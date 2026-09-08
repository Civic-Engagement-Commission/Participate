# frozen_string_literal: true

module Decidim
  module Participate
    module TaxonomyMaxPerFilterValidatable
      extend ActiveSupport::Concern

      included do
        validate :taxonomies_within_max_per_filter
      end

      def taxonomies_within_max_per_filter
        max = [current_component.settings.max_taxonomies_per_filter.to_i, 1].max

        taxonomy_filters.each do |filter|
          selected_count = (compact_taxonomies & filter.filter_taxonomy_ids).size
          next if selected_count <= max

          errors.add(:taxonomies, :too_many, count: max)
        end
      end
    end
  end
end
