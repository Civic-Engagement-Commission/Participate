# frozen_string_literal: true

module Decidim
  module Airtable
    class RunImportJob < ApplicationJob
      queue_as :default

      def perform(import_configuration_id, _requested_by_user_id = nil)
        import_configuration = Decidim::Airtable::ImportConfiguration.find_by(id: import_configuration_id)
        return if import_configuration.blank?

        Decidim::Airtable::RunImport.call(import_configuration:)
      end
    end
  end
end
