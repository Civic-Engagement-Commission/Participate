# frozen_string_literal: true

Rails.application.config.to_prepare do
  Decidim.component_registry.find(:proposals).tap do |component|
    component.settings(:global) do |settings|
      next if settings.attributes.has_key?(:max_taxonomies_per_filter)

      Decidim::DecidimAwesome.hash_append!(
        settings.attributes,
        :taxonomy_filters,
        :max_taxonomies_per_filter,
        Decidim::SettingsManifest::Attribute.new(type: :text)
      )
    end

    component.settings(:global) do |settings|
      next if settings.attributes.has_key?(:taxonomies_per_filter_element)

      Decidim::DecidimAwesome.hash_append!(
        settings.attributes,
        :max_taxonomies_per_filter,
        :taxonomies_per_filter_element,
        Decidim::SettingsManifest::Attribute.new(type: :text)
      )
    end
  end

  [Decidim::Proposals::ProposalForm, Decidim::Proposals::Admin::ProposalBaseForm].each do |form_klass|
    next if form_klass.include?(Decidim::Nyc::TaxonomyMaxPerFilterValidatable)

    form_klass.include(Decidim::Nyc::TaxonomyMaxPerFilterValidatable)
  end

  unless Decidim::Proposals::ApplicationHelper.include?(Decidim::Proposals::TaxonomiesMultiselectHelper)
    Decidim::Proposals::ApplicationHelper.include(Decidim::Proposals::TaxonomiesMultiselectHelper)
  end

  Decidim::Admin::SettingsHelper.prepend(Decidim::Nyc::SettingsHelperOverride) unless Decidim::Admin::SettingsHelper.include?(Decidim::Nyc::SettingsHelperOverride)
end
