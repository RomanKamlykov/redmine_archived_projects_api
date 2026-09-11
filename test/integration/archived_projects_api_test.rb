# frozen_string_literal: true

require File.expand_path('../../../../test/test_helper', __dir__)

class ArchivedProjectsApiTest < Redmine::ApiTest::Base
  # Default fixtures never set a `status`, so every project starts out
  # active; each test archives what it needs itself.

  def archive_project(id)
    Project.find(id).update_column(:status, Project::STATUS_ARCHIVED)
  end

  # -- index -----------------------------------------------------------

  test "GET /projects.json without a status filter should not return archived projects" do
    archive_project(2)
    get '/projects.json', :headers => credentials('admin')
    assert_response :success

    ids = ActiveSupport::JSON.decode(response.body)['projects'].pluck('id')
    assert_not_includes ids, 2
  end

  test "GET /projects.json?status=1 as admin should not return archived projects" do
    archive_project(2)
    get '/projects.json?status=1', :headers => credentials('admin')
    assert_response :success

    ids = ActiveSupport::JSON.decode(response.body)['projects'].pluck('id')
    assert_not_includes ids, 2
  end

  test "GET /projects.json?status=9 as admin should return only archived projects" do
    archive_project(2)
    get '/projects.json?status=9', :headers => credentials('admin')
    assert_response :success

    json = ActiveSupport::JSON.decode(response.body)
    assert_equal [2], json['projects'].pluck('id')
    assert_equal 9, json['projects'].first['status']
    assert_equal 1, json['total_count']
  end

  test "GET /projects.xml?status=9 as admin should return archived projects" do
    archive_project(2)
    get '/projects.xml?status=9', :headers => credentials('admin')
    assert_response :success
    assert_equal 'application/xml', @response.media_type

    assert_select 'projects>project>id', :text => '2'
    assert_select 'projects>project>status', :text => '9'
  end

  test "GET /projects.json?status=9 as admin should return archived descendants" do
    assert Project.find(1).archive
    get '/projects.json?status=9', :headers => credentials('admin')
    assert_response :success

    json = ActiveSupport::JSON.decode(response.body)
    assert_equal [1, 3, 4, 5, 6].sort, json['projects'].pluck('id').sort
    assert_equal 5, json['total_count']
  end

  test "GET /projects.json?status=9|1 as admin should return archived and active projects" do
    archive_project(2)
    get '/projects.json?status=9|1', :headers => credentials('admin')
    assert_response :success

    ids = ActiveSupport::JSON.decode(response.body)['projects'].pluck('id')
    assert_includes ids, 2
    assert_includes ids, 1
  end

  test "GET /projects.json?status=* as admin should return active closed and archived projects" do
    archive_project(2)
    Project.find(4).close
    get '/projects.json?status=*', :headers => credentials('admin')
    assert_response :success

    ids = ActiveSupport::JSON.decode(response.body)['projects'].pluck('id')
    assert_includes ids, 1 # active
    assert_includes ids, 4 # closed
    assert_includes ids, 2 # archived
  end

  test "GET /projects.json?status=* as admin should not return projects scheduled for deletion" do
    Project.find(3).update_column(:status, Project::STATUS_SCHEDULED_FOR_DELETION)
    get '/projects.json?status=*', :headers => credentials('admin')
    assert_response :success

    ids = ActiveSupport::JSON.decode(response.body)['projects'].pluck('id')
    assert_not_includes ids, 3
  end

  test "GET /projects.json?status=9 as admin should not return projects scheduled for deletion" do
    Project.find(3).update_column(:status, Project::STATUS_SCHEDULED_FOR_DELETION)
    get '/projects.json?status=9', :headers => credentials('admin')
    assert_response :success

    json = ActiveSupport::JSON.decode(response.body)
    assert_equal [], json['projects']
    assert_equal 0, json['total_count']
  end

  test "GET /projects.json?status=9 total_count should match the returned projects" do
    assert Project.find(1).archive
    get '/projects.json?status=9', :headers => credentials('admin')
    assert_response :success

    json = ActiveSupport::JSON.decode(response.body)
    assert_equal json['projects'].size, json['total_count']
  end

  test "GET /projects.json?status=9 as non admin should not return archived projects" do
    archive_project(4)
    get '/projects.json?status=9', :headers => credentials('jsmith')
    assert_response :success

    json = ActiveSupport::JSON.decode(response.body)
    assert_equal [], json['projects']
  end

  test "GET /projects.json?status=9 anonymous should not return archived projects" do
    archive_project(4)
    get '/projects.json?status=9'
    assert_response :success

    json = ActiveSupport::JSON.decode(response.body)
    assert_equal [], json['projects']
  end

  test "GET /projects.json?status=9&limit=1 as admin should paginate" do
    assert Project.find(1).archive
    get '/projects.json?status=9&limit=1', :headers => credentials('admin')
    assert_response :success

    json = ActiveSupport::JSON.decode(response.body)
    assert_equal 1, json['projects'].size
    assert_equal 1, json['limit']
    assert_equal 5, json['total_count']
  end

  test "GET /projects.csv should not return archived projects" do
    archive_project(2)
    get '/projects.csv', :headers => credentials('admin')
    assert_response :success
    assert_not_includes response.body, 'OnlineStore'
  end

  test "GET /projects should not return archived projects in HTML" do
    archive_project(2)
    log_user('admin', 'admin')
    get '/projects'
    assert_response :success
    assert_select 'a', :text => 'OnlineStore', :count => 0
  end

  # -- show --------------------------------------------------------------

  test "GET /projects/:id.json as admin should return the archived project" do
    archive_project(2)
    get '/projects/2.json', :headers => credentials('admin')
    assert_response :success

    json = ActiveSupport::JSON.decode(response.body)
    assert_equal 9, json['project']['status']
  end

  test "GET /projects/:identifier.xml as admin should return the archived project" do
    archive_project(2)
    get '/projects/onlinestore.xml', :headers => credentials('admin')
    assert_response :success
    assert_select 'project>status', :text => '9'
  end

  test "GET /projects/:id.json as non admin should return 403" do
    archive_project(2)
    get '/projects/2.json', :headers => credentials('jsmith')
    assert_response :forbidden
  end

  test "GET /projects/:id.json anonymous should return 403" do
    archive_project(2)
    get '/projects/2.json'
    assert_response :forbidden
  end

  test "GET /projects/:id as admin should still return 403 in HTML for an archived project" do
    archive_project(2)
    log_user('admin', 'admin')
    get '/projects/2'
    assert_response :forbidden
  end

  test "GET /projects/:id.json as admin should be unchanged for an active project" do
    get '/projects/1.json', :headers => credentials('admin')
    assert_response :success

    json = ActiveSupport::JSON.decode(response.body)
    assert_equal 1, json['project']['status']
  end

  test "GET /projects/:id.json as admin should return the archived parent" do
    assert Project.find(1).archive
    get '/projects/3.json', :headers => credentials('admin')
    assert_response :success

    json = ActiveSupport::JSON.decode(response.body)
    assert_equal 1, json['project']['parent']['id']
  end

  test "GET /projects/:id.xml as admin should return the archived parent" do
    assert Project.find(1).archive
    get '/projects/3.xml', :headers => credentials('admin')
    assert_response :success
    assert_select 'project>parent[id="1"]'
  end

  test "GET /projects/:id.json?include=enabled_modules as admin should return enabled modules" do
    archive_project(2)
    get '/projects/2.json?include=enabled_modules', :headers => credentials('admin')
    assert_response :success

    json = ActiveSupport::JSON.decode(response.body)
    assert json['project']['enabled_modules'].present?
  end

  test "GET /projects/:id.json?include=trackers as admin should omit trackers" do
    archive_project(2)
    get '/projects/2.json?include=trackers', :headers => credentials('admin')
    assert_response :success

    # Unauthorized :include entries are omitted entirely rather than
    # rendered as an empty array - see the "GET /projects.xml with
    # include=trackers without view_issues permission" core test for the
    # same behaviour with a non-archived project.
    json = ActiveSupport::JSON.decode(response.body)
    assert_nil json['project']['trackers']
  end

  # -- writes on an archived project stay blocked -------------------------

  test "PUT /projects/:id.json as admin should still return 403 on an archived project" do
    archive_project(2)
    put '/projects/2.json', :params => {:project => {:name => 'Renamed'}}, :headers => credentials('admin')
    assert_response :forbidden
  end

  test "PUT /projects/:id/close.json as admin should still return 403 on an archived project" do
    archive_project(2)
    put '/projects/2/close.json', :headers => credentials('admin')
    assert_response :forbidden
  end

  test "PUT /projects/:id/reopen.json as admin should still return 403 on an archived project" do
    archive_project(2)
    put '/projects/2/reopen.json', :headers => credentials('admin')
    assert_response :forbidden
  end

  test "PUT /projects/:id/unarchive.xml as admin should still succeed on an archived project" do
    archive_project(2)
    put '/projects/2/unarchive.xml', :headers => credentials('admin')
    assert_response :no_content
    assert Project.find(2).active?
  end
end
