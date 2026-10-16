# frozen_string_literal: true

module Decidim
  module Nyc
    module TaxonomyRequiredPerFilterValidatable
      extend ActiveSupport::Concern

      included do
        validate :taxonomies_present_per_filter, if: -> { Decidim::Nyc::TaxonomyFilterSettings.required? }
      end

      def taxonomies_present_per_filter
        taxonomy_filters.each do |filter|
          filter_taxonomy_ids = filter.filter_taxonomy_ids
          next if filter_taxonomy_ids.empty?
          next if compact_taxonomies.intersect?(filter_taxonomy_ids)

          errors.add(Decidim::Nyc::TaxonomyFilterSettings.error_key(filter),
                     errors.generate_message(:taxonomies, :blank_for_filter, filter: translated_attribute(filter.name)))
        end
      end
    end
  end
end
