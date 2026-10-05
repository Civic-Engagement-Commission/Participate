# frozen_string_literal: true

module Decidim
  module Nyc
    # Radio buttons for a taxonomy filter need a name scoped to that filter
    # (`taxonomies_by_filter[filter_id]`), otherwise the browser treats all
    # radio buttons across every filter as a single, mutually exclusive group
    # (native HTML radio grouping is based solely on the `name` attribute).
    # This concern receives those per-filter values and merges them into the
    # regular `taxonomies` array so validation and persistence stay unaware
    # of the split.
    module TaxonomyPerFilterRadioAttributes
      extend ActiveSupport::Concern

      included do
        attribute :taxonomies_by_filter, Hash, default: {}
      end

      def initialize(attributes = {})
        super

        return if taxonomies_by_filter.blank?

        self.taxonomies = (taxonomies + taxonomies_by_filter.values.compact.map(&:to_i)).uniq
      end
    end
  end
end
