# frozen_string_literal: true

module Decidim
  module Airtable
    class RunImport < Decidim::Command
      def initialize(import_configuration:, current_user:, import_run: nil)
        @import_configuration = import_configuration
        @current_user = current_user
        @import_run = import_run
      end

      def call
        return broadcast(:invalid) unless import_configuration.active?
        return broadcast(:invalid, error: :importing_user_missing) unless current_user&.organization == import_configuration.organization

        component = target_component
        return broadcast(:invalid, error: :target_component_missing) unless component

        records = Decidim::Airtable::Api::Records.new.all(
          base_id: import_configuration.airtable_base_id,
          table_id: import_configuration.airtable_table_id,
          view_id: import_configuration.airtable_view_id
        )

        result = process_records(records, proposal_data_mapper(component))
        broadcast(:ok, result.merge(fetched_count: records.length, mapped_count: records.length))
      rescue Decidim::Airtable::Api::Error, ArgumentError, TypeError => e
        broadcast(:invalid, error: e.message)
      end

      private

      attr_reader :import_configuration, :current_user, :import_run

      def target_component
        component_id = import_configuration.settings&.dig("decidim_component_id")
        return if component_id.blank?

        component = Decidim::Component.find_by(id: component_id, manifest_name: "proposals")
        return unless component&.participatory_space&.organization == import_configuration.organization

        component
      end

      def proposal_data_mapper(component)
        Decidim::Airtable::ProposalDataMapper.new(
          import_configuration:,
          component:
        )
      end

      def process_records(records, mapper)
        results = { created_count: 0, updated_count: 0, failed_count: 0, errors: [] }

        records.each do |record|
          if cancellation_requested?
            results[:cancelled] = true
            break
          end

          mapped_record = mapper.map(record)

          Decidim::Airtable::ProcessImportRow.call(import_configuration:, current_user:, mapped_record:) do
            on(:ok) do |result|
              results[:"#{result[:operation]}_count"] += 1
            end
            on(:invalid) do |result|
              results[:failed_count] += 1
              results[:errors] << {
                airtable_record_id: mapped_record[:airtable_record_id],
                proposal_title: mapped_value(mapped_record, :title),
                proposal_reference: mapped_record.dig(:proposal_data, :reference),
                error: result[:error]
              }
            end
          end
        end

        results
      end

      def cancellation_requested?
        run = import_run&.reload
        run.present? && (run.status_cancelling? || run.status_cancelled?)
      end

      def mapped_value(mapped_record, attribute)
        locale = import_configuration.organization.default_locale
        mapped_record.dig(:proposal_data, :"#{attribute}/#{locale}")
      end
    end
  end
end
