# frozen_string_literal: true

module Decidim
  module Nyc
    module TaxonomyMaxPerFilterValidatable
      extend ActiveSupport::Concern

      included do
        validate :taxonomies_within_max_per_filter
      end

      def taxonomies_within_max_per_filter
        taxonomy_filters.each do |filter|
          max = Decidim::Nyc::TaxonomyFilterSettings.max_for(current_component.settings, filter)
          selected_count = (compact_taxonomies & filter.filter_taxonomy_ids).size
          next if selected_count <= max

          errors.add(:taxonomies, :too_many, count: max)
        end
      end
    end
  end
end
