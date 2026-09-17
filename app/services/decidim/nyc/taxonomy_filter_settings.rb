# frozen_string_literal: true

module Decidim
  module Nyc
    module TaxonomyFilterSettings
      DEFAULT_MAX = 1
      DEFAULT_ELEMENT = "select"
      ELEMENTS = %w(select checkbox).freeze

      module_function

      # settings: Decidim::SettingsManifest schema instance (component.settings)
      # filter: Decidim::TaxonomyFilter
      def max_for(settings, filter)
        value = parse(settings.max_taxonomies_per_filter)[filter.id.to_s]
        [value.to_i, 1].max
      end

      def element_for(settings, filter)
        value = parse(settings.taxonomies_per_filter_element)[filter.id.to_s]
        ELEMENTS.include?(value) ? value : DEFAULT_ELEMENT
      end

      def parse(raw_json)
        JSON.parse(raw_json.presence || "{}")
      rescue JSON::ParserError
        {}
      end
    end
  end
end
