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
          normalized_mappings = form.normalized_field_mappings
          (import_configuration.settings || {}).merge(
            "proposal_field_mappings" => normalized_mappings,
            "proposal_field_mappings_snapshot" => field_mappings_snapshot(normalized_mappings)
          )
        end

        def field_mappings_snapshot(mappings)
          metadata_by_value = proposal_field_options.metadata_by_value

          mappings.each_with_object({}) do |(airtable_field_id, mapped_value), output|
            metadata = metadata_by_value[mapped_value]
            next unless metadata

            output[airtable_field_id.to_s] = metadata.stringify_keys.merge("value" => mapped_value)
          end
        end

        def proposal_field_options
          @proposal_field_options ||= Decidim::Airtable::ProposalFieldOptions.new(import_configuration.organization)
        end
      end
    end
  end
end
