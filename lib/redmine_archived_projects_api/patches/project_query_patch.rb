# frozen_string_literal: true

module RedmineArchivedProjectsApi
  module Patches
    # Lets a ProjectQuery return archived projects.
    #
    # The flag is opt-in and is only ever set by ProjectsControllerPatch, for
    # an administrator issuing an API request that explicitly asked for
    # archived projects (status=9, or status=* rewritten to the full status
    # list). Nothing in the HTML paths sets it, so the project list, the admin
    # project list (ProjectAdminQuery, a subclass) and saved queries all keep
    # behaving exactly as before.
    module ProjectQueryPatch
      # The statuses a query may return once include_archived is set.
      # Project::STATUS_SCHEDULED_FOR_DELETION (10) is deliberately excluded:
      # unlike ProjectAdminQuery, this plugin must never expose projects that
      # are queued for asynchronous destruction (see DestroyProjectJob).
      INCLUDED_STATUSES = [
        Project::STATUS_ACTIVE,
        Project::STATUS_CLOSED,
        Project::STATUS_ARCHIVED
      ].freeze

      attr_accessor :include_archived

      # Project.visible resolves to Project.allowed_to_condition(user,
      # :view_project), which hardcodes "projects.status IN (1, 5)" even for
      # administrators (:view_project belongs to no project module, so no
      # other clause is ever added). Because include_archived is only ever set
      # for an administrator (see ProjectsControllerPatch), dropping .visible
      # and applying an explicit status whitelist is equivalent to "admin
      # visibility, plus archived" - never broader.
      #
      # Query#statement silently drops every filter clause when the query is
      # invalid, so fall back to core behaviour in that case rather than
      # returning archived projects for a request whose filters could not be
      # applied.
      def base_scope
        return super unless include_archived && valid?

        Project.where(statement).where(:status => INCLUDED_STATUSES)
      end

      # Cosmetic: nothing validates list filter values against this list (see
      # Query#validate_query_filters), so it has no effect on which projects a
      # query can return. Kept so the query stays self-describing for
      # anything that introspects available_filters. No-op unless
      # include_archived is set, so ProjectAdminQuery - which defines its own
      # project_statuses_values and calls super - is unaffected.
      def project_statuses_values
        values = super
        values << [l(:project_status_archived), Project::STATUS_ARCHIVED.to_s] if include_archived
        values
      end
    end
  end
end
