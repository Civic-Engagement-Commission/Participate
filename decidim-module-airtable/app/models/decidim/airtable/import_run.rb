# frozen_string_literal: true

module Decidim
  module Airtable
    class ImportRun < ApplicationRecord
      self.table_name = "decidim_airtable_import_runs"

      belongs_to :import_configuration,
                 class_name: "Decidim::Airtable::ImportConfiguration",
                 foreign_key: :decidim_airtable_import_configuration_id,
                 inverse_of: :import_runs
      belongs_to :requested_by,
                 class_name: "Decidim::User",
                 foreign_key: :decidim_user_id,
                 optional: true,
                 inverse_of: false

      enum :status, {
        pending: "pending",
        running: "running",
        cancelling: "cancelling",
        cancelled: "cancelled",
        completed: "completed",
        completed_with_errors: "completed_with_errors",
        failed: "failed"
      }, prefix: true

      scope :active, -> { where(status: %w(pending running cancelling)) }
      scope :latest_first, -> { order(created_at: :desc) }

      validates :status, presence: true

      def complete!(result)
        failed_count = result.fetch(:failed_count, 0).to_i
        update!(
          status: failed_count.positive? ? :completed_with_errors : :completed,
          fetched_count: result.fetch(:fetched_count, 0),
          created_count: result.fetch(:created_count, 0),
          updated_count: result.fetch(:updated_count, 0),
          failed_count:,
          error_details: result.fetch(:errors, []),
          completed_at: Time.current
        )
      end

      def fail!(message)
        update!(status: :failed, last_error: message, completed_at: Time.current)
      end

      def request_cancel!
        requested = false

        with_lock do
          if status_pending?
            update!(status: :cancelled, completed_at: Time.current)
            requested = true
          elsif status_running?
            update!(status: :cancelling)
            requested = true
          end
        end

        requested
      end

      def force_reset!
        reset = false

        with_lock do
          next unless status_pending? || status_running? || status_cancelling?

          update!(
            status: :cancelled,
            last_error: "Run status force-reset by an administrator. The worker is not terminated.",
            completed_at: Time.current
          )
          reset = true
        end

        reset
      end

      def cancel!(result = {})
        update!(
          status: :cancelled,
          fetched_count: result.fetch(:fetched_count, fetched_count),
          created_count: result.fetch(:created_count, created_count),
          updated_count: result.fetch(:updated_count, updated_count),
          failed_count: result.fetch(:failed_count, failed_count),
          error_details: result.fetch(:errors, error_details),
          completed_at: Time.current
        )
      end
    end
  end
end
