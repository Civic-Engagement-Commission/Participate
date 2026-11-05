# frozen_string_literal: true

module Decidim
  module Airtable
    class ProposalCustomFieldsUpdater
      def initialize(organization:, component:, current_user:)
        @organization = organization
        @component = component
        @current_user = current_user
      end

      def apply(proposal, mappings)
        return if mappings.empty?
        raise Error, "Decidim Awesome custom fields are unavailable" unless awesome_custom_fields_available?

        config = awesome_config
        custom_field_groups.each { |group| apply_group(proposal, config, mappings, group) }
      rescue JSON::ParserError, Nokogiri::XML::SyntaxError => e
        raise Error, "Could not map Decidim Awesome custom fields: #{e.message}"
      end

      private

      attr_reader :organization, :component, :current_user

      def awesome_custom_fields_available?
        defined?(Decidim::DecidimAwesome::Config) && defined?(Decidim::DecidimAwesome::CustomFields)
      end

      def awesome_config
        Decidim::DecidimAwesome::Config.new(organization).tap do |config|
          config.context_from_component!(component)
          config.application_context!(current_user:)
        end
      end

      def custom_field_groups
        [
          ["public", "proposal_custom_field", :body],
          ["private", "proposal_private_custom_field", :private_body]
        ]
      end

      def apply_group(proposal, config, mappings, group)
        visibility, config_key, attribute = group
        field_mappings = mappings.select { |mapping| mapping.dig(:metadata, "visibility") == visibility }
        return if field_mappings.empty?

        current_value = current_field_value(proposal, attribute)
        definitions = config.collect_sub_configs_values(config_key)
        xml = build_xml(definitions, current_value, field_mappings)
        assign_field_value(proposal, attribute, xml)
      end

      def current_field_value(proposal, attribute)
        attribute == :private_body ? proposal.public_send(attribute) : proposal.body[organization.default_locale]
      end

      def assign_field_value(proposal, attribute, xml)
        if attribute == :private_body
          raise Error, "Decidim Awesome private proposal fields are unavailable" unless proposal.respond_to?(:private_body=)

          proposal.private_body = xml
        else
          proposal.body = proposal.body.to_h.merge(organization.default_locale => xml)
        end
      end

      def build_xml(definitions, current_value, mappings)
        fields = Decidim::DecidimAwesome::CustomFields.new(definitions)
        fields.apply_xml(current_value) if current_value.to_s.include?("decidim_awesome-custom_fields")
        mappings.each { |mapping| assign_field_value!(fields.fields, mapping) }

        Nokogiri::XML::Builder.new(encoding: "UTF-8") do |xml|
          xml.xml do
            xml.dl("class" => "decidim_awesome-custom_fields", "data-generator" => "decidim_awesome") do
              fields.fields.each { |field| append_field_xml(xml, field) }
            end
          end
        end.to_xml
      end

      def append_field_xml(xml, field)
        return if field["name"].blank?

        values = Array(field["userData"]).compact_blank
        return if values.empty?

        xml.dt(field["label"], "name" => field["name"])
        xml.dd("id" => field["name"], "name" => field["type"]) do
          values.each { |value| append_field_value(xml, field, value) }
        end
      end

      def append_field_value(xml, field, value)
        option = Array(field["values"]).find { |entry| entry["value"].to_s == value.to_s }
        display_value = option&.fetch("label", nil).presence || value.to_s
        attributes = {}
        attributes["alt"] = value.to_s if option || field["type"] == "date"
        xml.div(display_value, attributes)
      end

      def assign_field_value!(fields, mapping)
        field_name = mapping.dig(:metadata, "name")
        field = fields.find { |item| item["name"] == field_name }
        raise Error, "Configured custom field '#{field_name}' is no longer available" unless field

        value = mapping.fetch(:value)
        field["userData"] = value.is_a?(Array) ? value.compact_blank.map(&:to_s) : [value.to_s]
      end

      class Error < StandardError; end
    end
  end
end
