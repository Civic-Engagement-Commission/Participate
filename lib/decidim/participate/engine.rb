# frozen_string_literal: true

module Decidim
  module Participate
    class Engine < ::Rails::Engine
      isolate_namespace Decidim::Participate

      initializer "decidim_participate.additional_proposal_options" do |_app|
        Decidim.component_registry.find(:proposals).tap do |component|
          component.settings(:global) do |settings|
            Decidim::DecidimAwesome.hash_append!(
              settings.attributes,
              :taxonomy_filters,
              :max_taxonomies_per_filter,
              Decidim::SettingsManifest::Attribute.new(type: :integer, default: 1)
            )
          end
        end
      end
    end
  end
end
