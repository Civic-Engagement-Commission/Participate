# frozen_string_literal: true

module Decidim
  module Airtable
    class RunImport < Decidim::Command
      def initialize(import_configuration:, current_user:)
        @import_configuration = import_configuration
        @current_user = current_user
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
        mapped_records = records.map do |record|
          proposal_data_mapper(component).map(record)
        end

        broadcast(:ok, process_mapped_records(mapped_records).merge(fetched_count: records.length, mapped_count: mapped_records.length))
      rescue Decidim::Airtable::Api::Error, ArgumentError, TypeError => e
        broadcast(:invalid, error: e.message)
      end

      private

      attr_reader :import_configuration, :current_user

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

      def process_mapped_records(mapped_records)
        results = { created_count: 0, updated_count: 0, failed_count: 0, errors: [] }

        mapped_records.each do |mapped_record|
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

      def mapped_value(mapped_record, attribute)
        locale = import_configuration.organization.default_locale
        mapped_record.dig(:proposal_data, :"#{attribute}/#{locale}")
      end
    end
  end
end
