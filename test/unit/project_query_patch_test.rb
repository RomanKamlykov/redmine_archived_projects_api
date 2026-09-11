# frozen_string_literal: true

require File.expand_path('../../../../test/test_helper', __dir__)

class ProjectQueryPatchTest < ActiveSupport::TestCase
  def setup
    User.current = User.find(1) # admin
  end

  def teardown
    User.current = nil
  end

  test "base_scope should exclude archived projects by default" do
    Project.find(2).update_column(:status, Project::STATUS_ARCHIVED)
    query = ProjectQuery.new(:name => '_')

    assert_not_includes query.base_scope.map(&:id), 2
  end

  test "base_scope with include_archived should include archived projects" do
    Project.find(2).update_column(:status, Project::STATUS_ARCHIVED)
    query = ProjectQuery.new(:name => '_')
    query.include_archived = true
    query.filters = {'status' => {:operator => '=', :values => %w[1 5 9]}}

    assert_includes query.base_scope.map(&:id), 2
  end

  test "base_scope with include_archived should exclude projects scheduled for deletion" do
    Project.find(2).update_column(:status, Project::STATUS_SCHEDULED_FOR_DELETION)
    query = ProjectQuery.new(:name => '_')
    query.include_archived = true
    query.filters = {'status' => {:operator => '=', :values => %w[1 5 9]}}

    assert_not_includes query.base_scope.map(&:id), 2
  end

  test "base_scope with include_archived should fall back to visible scope when the query is invalid" do
    Project.find(2).update_column(:status, Project::STATUS_ARCHIVED)
    # A blank name fails Query's own `validates_presence_of :name`, exercising
    # the `valid?` guard in base_scope regardless of the filters given.
    query = ProjectQuery.new(:name => '')
    query.include_archived = true
    query.filters = {'status' => {:operator => '=', :values => %w[9]}}

    assert_not query.valid?
    assert_not_includes query.base_scope.map(&:id), 2
  end

  test "project_statuses_values should not include archived by default" do
    query = ProjectQuery.new(:name => '_')

    assert_not_includes query.project_statuses_values.map(&:last), Project::STATUS_ARCHIVED.to_s
  end

  test "project_statuses_values should include archived when include_archived is set" do
    query = ProjectQuery.new(:name => '_')
    query.include_archived = true

    assert_includes query.project_statuses_values.map(&:last), Project::STATUS_ARCHIVED.to_s
  end

  test "ProjectAdminQuery should not gain a duplicate archived entry" do
    query = ProjectAdminQuery.new(:name => '_')

    archived_entries = query.project_statuses_values.select {|_, v| v == Project::STATUS_ARCHIVED.to_s}
    assert_equal 1, archived_entries.size
  end
end
