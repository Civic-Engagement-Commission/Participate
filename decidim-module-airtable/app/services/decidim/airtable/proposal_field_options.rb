# frozen_string_literal: true

module Decidim
  module Airtable
    class ProposalFieldOptions
      CUSTOM_VALUE_PREFIX = "awesome_custom"
      ATTACHMENTS_VALUE = "attachments"
      ATTACHMENT_AIRTABLE_FIELD_TYPES = %w(multipleAttachments attachment).freeze
      WRITEBACK_OPTIONS = {
        "writeback_proposal_id" => "decidim.airtable.admin.import_configurations.show.proposal_fields.writeback_proposal_id",
        "writeback_proposal_url" => "decidim.airtable.admin.import_configurations.show.proposal_fields.writeback_proposal_url"
      }.freeze
      AUTHORS_LOOKUP_OPTIONS = {
        "authors_by_nickname" => "decidim.airtable.admin.import_configurations.show.proposal_fields.authors_by_nickname",
        "authors_by_email" => "decidim.airtable.admin.import_configurations.show.proposal_fields.authors_by_email"
      }.freeze

      STANDARD_FIELDS = {
        "title" => "decidim.airtable.admin.import_configurations.show.proposal_fields.title",
        "body" => "decidim.airtable.admin.import_configurations.show.proposal_fields.body",
        "address" => "decidim.airtable.admin.import_configurations.show.proposal_fields.address",
        "latitude" => "decidim.airtable.admin.import_configurations.show.proposal_fields.latitude",
        "longitude" => "decidim.airtable.admin.import_configurations.show.proposal_fields.longitude",
        "reference" => "decidim.airtable.admin.import_configurations.show.proposal_fields.reference",
        "cost" => "decidim.airtable.admin.import_configurations.show.proposal_fields.cost",
        "state" => "decidim.airtable.admin.import_configurations.show.proposal_fields.state",
        "published_at" => "decidim.airtable.admin.import_configurations.show.proposal_fields.published_at"
      }.freeze

      def initialize(organization)
        @organization = organization
      end

      def for_select(field: nil, selected_value: nil)
        [none_option] + standard_options + authors_options + custom_options + taxonomy_options + writeback_options + attachment_options(field:, selected_value:)
      end

      def grouped_for_select(field: nil, selected_value: nil)
        groups = []
        groups << [I18n.t("decidim.airtable.admin.import_configurations.show.proposal_fields.groups.standard"), standard_options]
        groups << [I18n.t("decidim.airtable.admin.import_configurations.show.proposal_fields.groups.authors"), authors_options]
        groups << [I18n.t("decidim.airtable.admin.import_configurations.show.proposal_fields.groups.awesome_custom"), custom_options] if custom_options.any?
        groups << [I18n.t("decidim.airtable.admin.import_configurations.show.proposal_fields.groups.taxonomies"), taxonomy_options] if taxonomy_options.any?
        groups << [I18n.t("decidim.airtable.admin.import_configurations.show.proposal_fields.groups.writeback"), writeback_options]
        attachments = attachment_options(field:, selected_value:)
        groups << [I18n.t("decidim.airtable.admin.import_configurations.show.proposal_fields.groups.attachments"), attachments] if attachments.any?
        groups.concat(other_groups)
        groups
      end

      def none_option
        [I18n.t("decidim.airtable.admin.import_configurations.show.proposal_fields.none"), ""]
      end

      def metadata_by_value
        @metadata_by_value ||= begin
          standard = standard_metadata
          custom = awesome_custom_fields.each_with_object({}) do |field, output|
            output[field[:value]] = field.except(:value).merge(kind: "awesome_custom")
          end
          taxonomies = root_taxonomies.each_with_object({}) do |taxonomy, output|
            output[taxonomy_value_for(taxonomy.id)] = {
              kind: "taxonomy_root",
              target: "taxonomy",
              taxonomy_id: taxonomy.id,
              label: taxonomy_label_for(taxonomy)
            }
          end
          attachments = {
            ATTACHMENTS_VALUE => {
              kind: "attachments",
              target: "attachments",
              label: I18n.t("decidim.airtable.admin.import_configurations.show.proposal_fields.attachments")
            }
          }
          authors = AUTHORS_LOOKUP_OPTIONS.keys.index_with do |value|
            {
              kind: "authors",
              target: "authors",
              lookup_by: value.delete_prefix("authors_by_"),
              label: I18n.t(AUTHORS_LOOKUP_OPTIONS[value])
            }
          end
          writeback = WRITEBACK_OPTIONS.keys.index_with do |value|
            {
              kind: "writeback",
              target: "airtable",
              attribute: value.delete_prefix("writeback_"),
              label: I18n.t(WRITEBACK_OPTIONS[value])
            }
          end
          standard.merge(authors).merge(custom).merge(taxonomies).merge(writeback).merge(attachments)
        end
      end

      private

      attr_reader :organization

      def standard_options
        STANDARD_FIELDS.map { |value, i18n_key| [I18n.t(i18n_key), value] }
      end

      def other_groups
        []
      end

      def taxonomy_options
        root_taxonomies.map do |taxonomy|
          [taxonomy_option_label(taxonomy), taxonomy_value_for(taxonomy.id)]
        end
      end

      def authors_options
        AUTHORS_LOOKUP_OPTIONS.map do |value, i18n_key|
          [I18n.t(i18n_key), value]
        end
      end

      def writeback_options
        WRITEBACK_OPTIONS.map do |value, i18n_key|
          [I18n.t(i18n_key), value]
        end
      end

      def attachment_options(field:, selected_value:)
        return [] unless attachment_mapping_available_for?(field, selected_value)

        [[I18n.t("decidim.airtable.admin.import_configurations.show.proposal_fields.attachments"), ATTACHMENTS_VALUE]]
      end

      def standard_metadata
        STANDARD_FIELDS.keys.index_with do |value|
          {
            kind: "standard",
            target: value,
            label: I18n.t(STANDARD_FIELDS[value])
          }
        end
      end

      def custom_options
        awesome_custom_fields.map do |field|
          [custom_option_label(field), field[:value]]
        end
      end

      def custom_option_label(field)
        if field[:visibility] == "private"
          I18n.t("decidim.airtable.admin.import_configurations.show.proposal_fields.custom_private", label: field[:label])
        else
          I18n.t("decidim.airtable.admin.import_configurations.show.proposal_fields.custom_public", label: field[:label])
        end
      end

      def awesome_custom_fields
        @awesome_custom_fields ||= begin
          fields = parsed_awesome_fields(awesome_public_fields, "public") + parsed_awesome_fields(awesome_private_fields, "private")
          fields.uniq { |field| field[:value] }
        end
      end

      def awesome_public_fields
        awesome_config_for(:proposal_custom_fields)
      end

      def awesome_private_fields
        awesome_config_for(:proposal_private_custom_fields)
      end

      def awesome_config_for(key)
        return {} unless defined?(Decidim::DecidimAwesome::Config)

        Decidim::DecidimAwesome::Config.new(organization).organization_config[key] || {}
      rescue StandardError
        {}
      end

      def parsed_awesome_fields(config, visibility)
        return [] if config.blank?

        Decidim::DecidimAwesome::CustomFields.new(config.values).fields.filter_map do |field|
          next if field["name"].blank?

          {
            value: custom_value_for(visibility, field["name"]),
            source: "decidim_awesome",
            visibility:,
            name: field["name"],
            label: field["label"].presence || field["name"],
            input_type: field["type"],
            subtype: field["subtype"]
          }
        end
      rescue StandardError
        []
      end

      def custom_value_for(visibility, field_name)
        "#{CUSTOM_VALUE_PREFIX}:#{visibility}:#{field_name}"
      end

      def taxonomy_value_for(taxonomy_id)
        "taxonomy_root:#{taxonomy_id}"
      end

      def taxonomy_option_label(taxonomy)
        I18n.t(
          "decidim.airtable.admin.import_configurations.show.proposal_fields.taxonomy",
          name: taxonomy_label_for(taxonomy)
        )
      end

      def taxonomy_label_for(taxonomy)
        taxonomy.translated_name
      rescue StandardError
        taxonomy.name[I18n.locale.to_s].presence || taxonomy.name.values.first || taxonomy.id.to_s
      end

      def root_taxonomies
        return Decidim::Taxonomy.none unless defined?(Decidim::Taxonomy)

        Decidim::Taxonomy.for(organization).roots
      rescue StandardError
        Decidim::Taxonomy.none
      end

      def attachment_mapping_available_for?(field, selected_value)
        return true if selected_value == ATTACHMENTS_VALUE
        return false if field.blank?

        ATTACHMENT_AIRTABLE_FIELD_TYPES.include?(field[:type].to_s)
      end
    end
  end
end
