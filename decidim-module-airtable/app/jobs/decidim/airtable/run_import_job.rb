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

        return unless start_run(import_run)

        outcome = nil
        result = nil
        Decidim::Airtable::RunImport.call(import_configuration:, current_user:, import_run:) do
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
          finish_run(import_run, result || {})
        else
          import_run&.fail!((result || {}).fetch(:error, "Import could not be started").to_s)
        end
      rescue StandardError => e
        mark_failed(import_run, e.message)
        raise
      end

      private

      def start_run(import_run)
        return true unless import_run

        should_run = false
        import_run.with_lock do
          if import_run.status_pending?
            import_run.update!(status: :running, started_at: Time.current)
            should_run = true
          elsif import_run.status_running?
            should_run = true
          elsif import_run.status_cancelling?
            import_run.cancel!
          end
        end
        should_run
      end

      def finish_run(import_run, result)
        return unless import_run

        import_run.with_lock do
          unless import_run.status_cancelled?
            if import_run.status_cancelling? || result[:cancelled]
              import_run.cancel!(result)
            elsif import_run.status_running?
              import_run.complete!(result)
            end
          end
        end
      end

      def mark_failed(import_run, message)
        return unless import_run

        import_run.with_lock do
          import_run.fail!(message) if import_run.status_pending? || import_run.status_running? || import_run.status_cancelling?
        end
      end
    end
  end
end
