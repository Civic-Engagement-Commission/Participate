# frozen_string_literal: true

module Decidim
  module Airtable
    module Admin
      class UpdateImportMapping < Decidim::Command
        delegate :current_user, to: :form

        def initialize(form, import_configuration)
          @form = form
          @import_configuration = import_configuration
        end

        def call
          return broadcast(:invalid) if form.invalid?

          Decidim.traceability.update!(
            import_configuration,
            current_user,
            settings: settings
          )

          broadcast(:ok, import_configuration)
        rescue ActiveRecord::RecordInvalid => e
          e.record.errors.each do |error|
            form.errors.add(error.attribute, error.type, **error.options)
          end
          broadcast(:invalid)
        end

        private

        attr_reader :form, :import_configuration

        def settings
          (import_configuration.settings || {}).merge(
            "proposal_field_mappings" => form.normalized_field_mappings
          )
        end
      end
    end
  end
end
