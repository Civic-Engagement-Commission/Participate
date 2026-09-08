# frozen_string_literal: true

module Decidim
  module Proposals
    module TaxonomiesMultiselectHelper
      include Decidim::TaxonomiesHelper

      def filter_taxonomy_items_multiselect_field(form, name, filter, max)
        label = decidim_sanitize_translated(filter.name)
        form.select(name, taxonomy_items_options_for_filter(filter), { include_blank: false, label: },
                    { name: "#{form.object_name}[#{name}][]", id: "#{name}-#{filter.id}", multiple: true,
                      data: { controller: "taxonomy-multiselect", "taxonomy-multiselect-max-value": max,
                              "taxonomy-multiselect-placeholder-value": I18n.t("decidim.taxonomies.prompt") } })
      end
    end
  end
end
