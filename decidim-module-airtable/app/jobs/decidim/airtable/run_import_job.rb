# frozen_string_literal: true

module Decidim
  module Airtable
    class RunImportJob < ApplicationJob
      queue_as :default

      def perform(import_configuration_id, requested_by_user_id = nil)
        import_configuration = Decidim::Airtable::ImportConfiguration.find_by(id: import_configuration_id)
        return if import_configuration.blank?

        current_user = Decidim::User.find_by(id: requested_by_user_id, organization: import_configuration.organization)
        return if current_user.blank?

        Decidim::Airtable::RunImport.call(import_configuration:, current_user:)
      end
    end
  end
end
