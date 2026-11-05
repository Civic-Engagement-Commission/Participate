# frozen_string_literal: true

module Decidim
  module Airtable
    class RunImport < Decidim::Command
      def initialize(import_configuration:)
        @import_configuration = import_configuration
      end

      def call
        return broadcast(:invalid) unless import_configuration.active?

        component = target_component
        return broadcast(:invalid, error: :target_component_missing) unless component

        records = Decidim::Airtable::Api::Records.new.all(
          base_id: import_configuration.airtable_base_id,
          table_id: import_configuration.airtable_table_id,
          view_id: import_configuration.airtable_view_id
        )
        mapped_records = records.map do |record|
          proposal_data_mapper.map(record)
        end

        broadcast(
          :ok,
          fetched_count: records.length,
          mapped_count: mapped_records.length,
          mapped_records: mapped_records
        )
      rescue Decidim::Airtable::Api::Error, ArgumentError, TypeError => e
        broadcast(:invalid, error: e.message)
      end

      private

      attr_reader :import_configuration

      def target_component
        component_id = import_configuration.settings&.dig("decidim_component_id")
        return if component_id.blank?

        component = Decidim::Component.find_by(id: component_id, manifest_name: "proposals")
        return unless component&.participatory_space&.organization == import_configuration.organization

        component
      end

      def proposal_data_mapper
        @proposal_data_mapper ||= Decidim::Airtable::ProposalDataMapper.new(
          import_configuration:,
          component: target_component
        )
      end
    end
  end
end
