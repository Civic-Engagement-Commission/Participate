# frozen_string_literal: true

module Decidim
  module Airtable
    module Admin
      class ImportMappingForm < Decidim::Form
        mimic :import_configuration

        WRITEBACK_MAPPING_VALUES = %w(writeback_proposal_id writeback_proposal_url).freeze
        ATTACHMENTS_MAPPING_VALUE = "attachments"
        ATTACHMENT_AIRTABLE_FIELD_TYPES = %w(multipleAttachments attachment).freeze
        PUBLISHED_AT_MAPPING_VALUE = "published_at"
        PUBLISHED_AT_AIRTABLE_FIELD_TYPES = %w(date dateTime createdTime lastModifiedTime formula).freeze

        attribute :id, Integer
        attribute :field_mappings, Hash, default: {}
        attribute :airtable_fields, Array, default: []

        validate :validate_unique_writeback_mappings
        validate :validate_attachments_mapping_types
        validate :validate_published_at_mapping_types

        def normalized_field_mappings
          (field_mappings || {}).to_h.stringify_keys.transform_values(&:presence).compact
        end

        private

        def validate_unique_writeback_mappings
          WRITEBACK_MAPPING_VALUES.each do |value|
            mapped_fields = normalized_field_mappings.select { |_field_id, mapped_value| mapped_value == value }.keys
            next if mapped_fields.size <= 1

            errors.add(
              :field_mappings,
              I18n.t(
                "decidim.airtable.admin.import_configurations.update.validation.writeback_target_mapped_more_than_once",
                target: mapping_label_for(value)
              )
            )
          end
        end

        def validate_attachments_mapping_types
          normalized_field_mappings.each do |field_id, mapped_value|
            next unless mapped_value == ATTACHMENTS_MAPPING_VALUE

            field = airtable_field_by_id(field_id)
            next if field.blank?
            next if ATTACHMENT_AIRTABLE_FIELD_TYPES.include?(field_type(field))

            errors.add(
              :field_mappings,
              I18n.t(
                "decidim.airtable.admin.import_configurations.update.validation.attachments_requires_file_field",
                field: field_label(field)
              )
            )
          end
        end

        def validate_published_at_mapping_types
          normalized_field_mappings.each do |field_id, mapped_value|
            next unless mapped_value == PUBLISHED_AT_MAPPING_VALUE

            field = airtable_field_by_id(field_id)
            next if field.blank?
            next if PUBLISHED_AT_AIRTABLE_FIELD_TYPES.include?(field_type(field))

            errors.add(
              :field_mappings,
              I18n.t(
                "decidim.airtable.admin.import_configurations.update.validation.published_at_requires_date_field",
                field: field_label(field)
              )
            )
          end
        end

        def airtable_field_by_id(field_id)
          @airtable_field_by_id ||= (airtable_fields || []).index_by { |field| field[:id].to_s }
          @airtable_field_by_id[field_id.to_s]
        end

        def field_type(field)
          field[:type].to_s
        end

        def field_label(field)
          field[:name].presence || field[:id].to_s
        end

        def mapping_label_for(value)
          I18n.t("decidim.airtable.admin.import_configurations.show.proposal_fields.#{value}")
        end
      end
    end
  end
end
