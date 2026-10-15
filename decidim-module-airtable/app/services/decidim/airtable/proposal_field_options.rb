# frozen_string_literal: true

module Decidim
  module Airtable
    class ProposalFieldOptions
      CUSTOM_VALUE_PREFIX = "awesome_custom"

      STANDARD_FIELDS = {
        "title" => "decidim.airtable.admin.import_configurations.show.proposal_fields.title",
        "body" => "decidim.airtable.admin.import_configurations.show.proposal_fields.body",
        "address" => "decidim.airtable.admin.import_configurations.show.proposal_fields.address",
        "latitude" => "decidim.airtable.admin.import_configurations.show.proposal_fields.latitude",
        "longitude" => "decidim.airtable.admin.import_configurations.show.proposal_fields.longitude",
        "reference" => "decidim.airtable.admin.import_configurations.show.proposal_fields.reference",
        "cost" => "decidim.airtable.admin.import_configurations.show.proposal_fields.cost",
        "state" => "decidim.airtable.admin.import_configurations.show.proposal_fields.state"
      }.freeze

      def initialize(organization)
        @organization = organization
      end

      def for_select
        [none_option] + standard_options + custom_options
      end

      def grouped_for_select
        groups = []
        groups << [I18n.t("decidim.airtable.admin.import_configurations.show.proposal_fields.groups.standard"), standard_options]
        groups << [I18n.t("decidim.airtable.admin.import_configurations.show.proposal_fields.groups.awesome_custom"), custom_options] if custom_options.any?
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
          standard.merge(custom)
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
    end
  end
end
