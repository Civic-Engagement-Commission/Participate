# frozen_string_literal: true

module Decidim
  module Airtable
    module Admin
      class ImportMappingForm < Decidim::Form
        mimic :import_configuration

        attribute :id, Integer
        attribute :field_mappings, Hash, default: {}

        def normalized_field_mappings
          (field_mappings || {}).to_h.stringify_keys.transform_values(&:presence).compact
        end
      end
    end
  end
end
