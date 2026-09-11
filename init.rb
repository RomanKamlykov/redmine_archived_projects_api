# frozen_string_literal: true

Redmine::Plugin.register :redmine_archived_projects_api do
  name        'Redmine Archived Projects API'
  author      'Roman Kamlykov'
  url         'https://github.com/RomanKamlykov/redmine_archived_projects_api'
  description 'Exposes archived projects (status 9) to administrators through the REST API'
  version     '1.0.0'
  requires_redmine :version_or_higher => '6.0.0'
end

# This file is `load`ed from Rails.application.config.to_prepare on every code
# reload (see lib/redmine/plugin_loader.rb). Prepend the patches directly here
# rather than from a nested `to_prepare` block: a nested block would register
# an additional callback on the executor on every reload, whereas
# Module#prepend is a no-op once the module is already in the ancestor chain.
# After a Zeitwerk reload both the patched class and the patch module are new
# constants, so simply re-running this file is exactly what re-establishes the
# patch.
#
# Do not `require`/`require_relative` the files below: plugins/<id>/lib is a
# Zeitwerk autoload root (eager_load: true), so referencing the constants is
# both necessary and sufficient for them to be loaded.
ProjectQuery.prepend       RedmineArchivedProjectsApi::Patches::ProjectQueryPatch
ProjectsController.prepend RedmineArchivedProjectsApi::Patches::ProjectsControllerPatch

# ProjectsHelper is mixed into a controller-generated helper module rather
# than used directly, so it is reopened and aliased instead of prepended -
# see the comment in projects_helper_patch.rb. #apply is idempotent (guarded
# by alias presence), safe to re-run on every reload.
RedmineArchivedProjectsApi::Patches::ProjectsHelperPatch.apply
