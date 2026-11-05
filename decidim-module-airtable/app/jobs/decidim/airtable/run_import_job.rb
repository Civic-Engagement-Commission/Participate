# frozen_string_literal: true

module Decidim
  module Airtable
    class RunImportJob < ApplicationJob
      queue_as :default

      def perform(import_configuration_id, requested_by_user_id = nil, import_run_id = nil)
        import_run = Decidim::Airtable::ImportRun.find_by(id: import_run_id)
        import_configuration = Decidim::Airtable::ImportConfiguration.find_by(id: import_configuration_id)
        return mark_failed(import_run, "Import configuration no longer exists") if import_configuration.blank?

        current_user = Decidim::User.find_by(id: requested_by_user_id, organization: import_configuration.organization)
        return mark_failed(import_run, "Requesting admin no longer exists") if current_user.blank?

        import_run&.update!(status: :running, started_at: Time.current)

        outcome = nil
        result = nil
        Decidim::Airtable::RunImport.call(import_configuration:, current_user:) do
          on(:ok) do |payload|
            outcome = :ok
            result = payload
          end
          on(:invalid) do |payload|
            outcome = :invalid
            result = payload
          end
        end

        if outcome == :ok
          import_run&.complete!(result || {})
        else
          import_run&.fail!((result || {}).fetch(:error, "Import could not be started").to_s)
        end
      rescue StandardError => e
        mark_failed(import_run, e.message)
        raise
      end

      private

      def mark_failed(import_run, message)
        import_run&.fail!(message)
      end
    end
  end
end
