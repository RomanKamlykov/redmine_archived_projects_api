# frozen_string_literal: true

module RedmineArchivedProjectsApi
  module Patches
    # index.api.rsb and show.api.rsb render <parent> only when
    # `project.parent.visible?`. Archiving cascades to descendants
    # (Project#archive!), so for any archived project below an archived root
    # the parent is archived too, visible? is false, and the client silently
    # loses the hierarchy link.
    #
    # Overriding the two templates would fix this, but plugin view paths are
    # prepended globally: our copies would then serve EVERY /projects.* API
    # call, not just archived ones, and would silently freeze every other
    # field in the response at whatever Redmine version this plugin was
    # written against. Instead we re-emit the parent from
    # render_api_includes, which both templates already call from inside
    # their `api.project do ... end` block, and change nothing else.
    #
    # ProjectsHelper is mixed into a controller-generated helper module
    # (ProjectsController's default helper module), not used directly as a
    # class - Module#prepend applied to a module after it has already been
    # `include`d elsewhere is not guaranteed to take effect for the class
    # that included it, depending on load order. Reopening the module and
    # aliasing avoids that risk entirely: it mutates ProjectsHelper's own
    # method table in place, which every includer sees immediately,
    # regardless of when the include happened. This mirrors the alias-based
    # style core itself uses for patching already-loaded third-party classes
    # (see the Doorkeeper patch in config/initializers/30-redmine.rb).
    #
    # Side effect: in the XML response the <parent> element then appears
    # after <custom_fields> instead of before <status>; JSON key order is
    # not significant.
    module ProjectsHelperPatch
      ORIGINAL_METHOD = :render_api_includes_without_archived_projects_api

      def self.apply
        return if ProjectsHelper.method_defined?(ORIGINAL_METHOD) ||
                  ProjectsHelper.private_method_defined?(ORIGINAL_METHOD)

        ProjectsHelper.class_eval do
          alias_method ORIGINAL_METHOD, :render_api_includes

          def render_api_includes(project, api)
            if project.archived? && User.current.admin? && project.parent && !project.parent.visible?
              api.parent(:id => project.parent.id, :name => project.parent.name)
            end
            send(RedmineArchivedProjectsApi::Patches::ProjectsHelperPatch::ORIGINAL_METHOD, project, api)
          end
        end
      end
    end
  end
end
