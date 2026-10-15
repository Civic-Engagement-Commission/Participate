# frozen_string_literal: true

module Decidim
  module Airtable
    module Admin
      class CreateImportConfiguration < Decidim::Command
        delegate :current_user, to: :form

        def initialize(form)
          @form = form
        end

        def call
          return broadcast(:invalid) if form.invalid?

          @import_configuration = Decidim.traceability.create!(
            Decidim::Airtable::ImportConfiguration,
            current_user,
            attributes
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

        def attributes
          {
            decidim_organization_id: form.organization.id,
            airtable_base_id: form.airtable_base_id,
            airtable_table_id: form.airtable_table_id,
            airtable_view_id: form.airtable_view_id,
            settings: settings,
            active: form.active
          }
        end

        def settings
          {
            "airtable_base_name" => form.airtable_base_name,
            "airtable_table_name" => form.airtable_table_name,
            "airtable_view_name" => form.airtable_view_name
          }.compact_blank
        end
      end
    end
  end
end
