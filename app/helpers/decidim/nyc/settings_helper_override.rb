# frozen_string_literal: true

module Decidim
  module Nyc
    module SettingsHelperOverride
      TAXONOMY_FILTER_JSON_SETTINGS = {
        max_taxonomies_per_filter: { "input-type": "number" },
        taxonomies_per_filter_element: {
          "input-type": "select",
          "input-options": Decidim::Nyc::TaxonomyFilterSettings::ELEMENTS.to_json
        }
      }.freeze

      def settings_attribute_input(form, attribute, name, i18n_scope, options = {})
        if TAXONOMY_FILTER_JSON_SETTINGS.has_key?(name)
          options = options.merge(
            data: {
              controller: "taxonomy-filter-json-editor",
              "taxonomy-filter-json-editor-filters-value": taxonomy_filters_for_json_editor.to_json
            }.merge(TAXONOMY_FILTER_JSON_SETTINGS[name].transform_keys { |k| "taxonomy-filter-json-editor-#{k}-value" })
          )
        end

        super
      end

      def taxonomy_filters_for_json_editor
        Decidim::TaxonomyFilter.where(id: @component&.settings&.taxonomy_filters).map do |filter|
          { id: filter.id, name: decidim_sanitize_translated(filter.name) }
        end
      end
    end
  end
end
