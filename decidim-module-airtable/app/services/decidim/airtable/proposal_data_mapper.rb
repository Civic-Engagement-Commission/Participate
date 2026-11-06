# frozen_string_literal: true

require "digest"

module Decidim
  module Airtable
    class ProposalDataMapper
      def initialize(import_configuration:, component:)
        @import_configuration = import_configuration
        @component = component
      end

      def map(record)
        fields = record.fetch(:fields, {})
        proposal_data = { component: }
        auxiliary_mappings = []

        field_mappings.each do |airtable_field_id, mapped_value|
          value = fields[airtable_field_id]

          if auxiliary_mapping?(mapped_value, value)
            auxiliary_mappings << {
              airtable_field_id: airtable_field_id,
              mapping: mapped_value,
              metadata: mapping_snapshot[airtable_field_id] || {},
              value: value
            }
            next
          end

          next if value.nil? || value == ""

          next unless Decidim::Airtable::ProposalFieldOptions::STANDARD_FIELDS.has_key?(mapped_value)

          proposal_data[proposal_attribute(mapped_value)] = normalize_value(mapped_value, value)
        end

        {
          airtable_record_id: record.fetch(:id),
          airtable_created_at: record[:created_at],
          row_checksum: Digest::SHA256.hexdigest(JSON.generate(fields.sort.to_h)),
          proposal_data: proposal_data,
          auxiliary_mappings: auxiliary_mappings
        }
      end

      private

      attr_reader :import_configuration, :component

      def field_mappings
        import_configuration.settings&.dig("proposal_field_mappings") || {}
      end

      def mapping_snapshot
        import_configuration.settings&.dig("proposal_field_mappings_snapshot") || {}
      end

      def auxiliary_mapping?(mapped_value, value)
        return true if mapped_value == "attachments" || mapped_value.start_with?("taxonomy_root:", "awesome_custom:", "writeback_")
        return false if mapped_value.start_with?("authors_by_") && value.blank?

        !Decidim::Airtable::ProposalFieldOptions::STANDARD_FIELDS.has_key?(mapped_value)
      end

      def proposal_attribute(mapped_value)
        return :"#{mapped_value}/#{import_configuration.organization.default_locale}" if %w(title body).include?(mapped_value)

        mapped_value.to_sym
      end

      def normalize_value(mapped_value, value)
        case mapped_value
        when "latitude", "longitude"
          Float(value)
        when "cost"
          BigDecimal(value.to_s)
        when "created_at", "published_at"
          value.is_a?(Time) ? value : Time.zone.parse(value.to_s)
        else
          value
        end
      end
    end
  end
end
