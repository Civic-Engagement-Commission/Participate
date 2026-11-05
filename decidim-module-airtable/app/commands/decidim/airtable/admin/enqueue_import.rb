# frozen_string_literal: true

module Decidim
  module Airtable
    module Admin
      class EnqueueImport < Decidim::Command
        def initialize(import_configuration, current_user)
          @import_configuration = import_configuration
          @current_user = current_user
        end

        def call
          return broadcast(:invalid) unless import_configuration.active?
          return broadcast(:invalid) unless current_user&.organization == import_configuration.organization
          return broadcast(:invalid) if import_configuration.import_runs.active.exists?

          import_run = import_configuration.import_runs.create!(requested_by: current_user, status: :pending)
          job = Decidim::Airtable::RunImportJob.perform_later(import_configuration.id, current_user.id, import_run.id)
          import_run.update!(job_id: job.job_id)

          broadcast(:ok, import_run)
        rescue StandardError => e
          import_run&.update(status: :failed, last_error: e.message, completed_at: Time.current)
          broadcast(:invalid)
        end

        private

        attr_reader :import_configuration, :current_user
      end
    end
  end
end
