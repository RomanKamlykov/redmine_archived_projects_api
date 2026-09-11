# frozen_string_literal: true

module RedmineArchivedProjectsApi
  module Patches
    module ProjectsControllerPatch
      # Accepted in ?status= to mean "every status this plugin exposes". Core
      # cannot express this on its own: the project "status" filter is
      # registered as :list, whose only operators are "=" and "!"
      # (Query#operators_by_filter_type), so add_short_filter turns a bare "*"
      # into the literal value '*' and the generated SQL becomes
      # `projects.status IN ('*')` - a type error on PostgreSQL and silently
      # wrong elsewhere. We detect the token and rewrite the filter instead.
      ALL_STATUSES_TOKEN = '*'

      private

      # ProjectsController#index builds its query through this method. The
      # query is only switched into "archived" mode when the caller is an
      # administrator issuing an API request that explicitly asked for
      # archived projects, so an unfiltered GET /projects.json is unchanged -
      # including when the query turns out to be invalid, in which case
      # ProjectQueryPatch#base_scope falls back to core behaviour anyway.
      def retrieve_project_query
        query = super
        return query unless archived_projects_requested?(query)

        query.include_archived = true
        if all_statuses_token?(query)
          query.add_filter('status', '=', ProjectQueryPatch::INCLUDED_STATUSES.map(&:to_s))
        end
        query
      end

      # ApplicationController#authorize denies every action on an archived
      # project: Project#allows_to? returns false for an archived project
      # before User#allowed_to? ever reaches its admin bypass. Let the
      # read-only API show action through for administrators and nothing
      # else - settings, edit, update, close, reopen, modules and bookmark all
      # keep the core (403) behaviour, as do archive, unarchive, destroy and
      # bulk_destroy, which are gated by require_admin rather than authorize.
      def authorize(ctrl = params[:controller], action = params[:action], global = false)
        return true if archived_project_api_show?(ctrl, action)

        super
      end

      def archived_projects_api_enabled?
        api_request? && User.current.admin?
      end

      def archived_project_api_show?(ctrl, action)
        archived_projects_api_enabled? &&
          request.get? &&
          ctrl.to_s == 'projects' &&
          action.to_s == 'show' &&
          @project.present? &&
          @project.archived?
      end

      def archived_projects_requested?(query)
        return false unless archived_projects_api_enabled?
        return false unless query.has_filter?('status')
        return false unless query.operator_for('status') == '='

        values = Array(query.values_for('status')).map(&:to_s)
        values.include?(Project::STATUS_ARCHIVED.to_s) || values.include?(ALL_STATUSES_TOKEN)
      end

      def all_statuses_token?(query)
        Array(query.values_for('status')).map(&:to_s).include?(ALL_STATUSES_TOKEN)
      end
    end
  end
end
