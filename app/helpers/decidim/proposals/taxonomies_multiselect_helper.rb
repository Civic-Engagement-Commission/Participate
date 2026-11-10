# frozen_string_literal: true

module Decidim
  module Proposals
    module TaxonomiesMultiselectHelper
      include Decidim::TaxonomiesHelper

      def filter_taxonomy_items_multiselect_field(form, name, filter, max)
        label = decidim_sanitize_translated(filter.name)
        form.select(name, taxonomy_items_options_for_filter(filter),
                    { include_blank: false, label:, required: Decidim::Nyc::TaxonomyFilterSettings.required? },
                    { name: "#{form.object_name}[#{name}][]", id: "#{name}-#{filter.id}", multiple: true,
                      data: { controller: "taxonomy-multiselect", "taxonomy-multiselect-max-value": max,
                              "taxonomy-multiselect-placeholder-value": I18n.t("decidim.taxonomies.prompt") } })
      end

      def filter_taxonomy_items_radio_field(form, name, filter)
        content_tag(:fieldset) do
          concat taxonomy_filter_legend(form, filter)
          concat form.error_for(Decidim::Nyc::TaxonomyFilterSettings.error_key(filter)).to_s
          concat form.collection_radio_buttons(
            name, taxonomy_items_options_for_filter(filter), :last, :first,
            {},
            { name: "#{form.object_name}[taxonomies_by_filter][#{filter.id}]" }
          ) { |b|
            item_id = "#{name}-#{filter.id}-#{b.value}"
            content_tag(:div) { b.label(for: item_id, class: "form__wrapper-checkbox-label") { b.radio_button(id: item_id) + b.text } }
          }
        end
      end

      def filter_taxonomy_items_checkboxes_field(form, name, filter, max)
        content_tag(:fieldset, data: { controller: "taxonomy-checkbox-limit",
                                       "taxonomy-checkbox-limit-max-value": max,
                                       action: "change->taxonomy-checkbox-limit#update" }) do
          concat taxonomy_filter_legend(form, filter)
          concat form.error_for(Decidim::Nyc::TaxonomyFilterSettings.error_key(filter)).to_s
          concat form.collection_check_boxes(
            name, taxonomy_items_options_for_filter(filter), :last, :first,
            {},
            { name: "#{form.object_name}[#{name}][]" }
          ) { |b|
            item_id = "#{name}-#{filter.id}-#{b.value}"
            content_tag(:div) { b.label(for: item_id, class: "form__wrapper-checkbox-label") { b.check_box(id: item_id) + b.text } }
          }
        end
      end

      private

      def taxonomy_filter_legend(form, filter)
        label = decidim_sanitize_translated(filter.name)
        label += form.send(:required_indicator) if Decidim::Nyc::TaxonomyFilterSettings.required?
        content_tag(:legend, label, class: "font-semibold")
      end
    end
  end
end
