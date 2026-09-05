# frozen_string_literal: true

Rails.application.config.to_prepare do
  Decidim.component_registry.find(:proposals).tap do |component|
    component.settings(:global) do |settings|
      next if settings.attributes.has_key?(:max_taxonomies_per_filter)

      Decidim::DecidimAwesome.hash_append!(
        settings.attributes,
        :taxonomy_filters,
        :max_taxonomies_per_filter,
        Decidim::SettingsManifest::Attribute.new(type: :integer, default: 1)
      )
    end
  end
end
