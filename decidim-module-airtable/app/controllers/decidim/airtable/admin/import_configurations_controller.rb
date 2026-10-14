# frozen_string_literal: true

module Decidim
  module Airtable
    module Admin
      class ImportConfigurationsController < Decidim::Airtable::Admin::ApplicationController
        before_action :import_configuration
        before_action :load_airtable_fields

        def show
          enforce_permission_to :read, :import, import_configuration:
          @form = form(Decidim::Airtable::Admin::ImportMappingForm).from_params(
            id: import_configuration.id,
            field_mappings: current_field_mappings
          )
        end

        def update
          enforce_permission_to :update, :import, import_configuration:
          @form = form(Decidim::Airtable::Admin::ImportMappingForm).from_params(import_mapping_params.merge(id: import_configuration.id))

          Decidim::Airtable::Admin::UpdateImportMapping.call(@form, import_configuration) do
            on(:ok) do
              redirect_to configure_import_path(import_configuration), notice: t("decidim.airtable.admin.import_configurations.update.success")
            end

            on(:invalid) do
              flash.now[:alert] = t("decidim.airtable.admin.import_configurations.update.error")
              render :show, status: :unprocessable_entity
            end
          end
        end

        private

        def import_configuration
          @import_configuration ||= Decidim::Airtable::ImportConfiguration
                                    .where(organization: current_organization)
                                    .find(params[:id])
        end

        def import_mapping_params
          params.require(:import_mapping_form).permit(field_mappings: {}).to_h
        end

        def current_field_mappings
          import_configuration.settings&.dig("proposal_field_mappings") || {}
        end

        def load_airtable_fields
          @airtable_fields = []
          table = fetch_airtable_table
          return unless table

          @airtable_fields = filtered_fields_for_table(table)
        rescue Decidim::Airtable::Api::Error
          @airtable_fields = []
          flash.now[:alert] = t("decidim.airtable.admin.import_configurations.show.fields_loading_error")
        end

        def fetch_airtable_table
          Decidim::Airtable::Api::Tables.new.for_base(import_configuration.airtable_base_id)
                                        .find { |item| item[:id] == import_configuration.airtable_table_id }
        end

        def filtered_fields_for_table(table)
          fields = table.fetch(:fields, [])
          visible_ids = visible_field_ids_for_table(table)
          return fields if visible_ids.empty?

          mapped_field_ids = current_field_mappings.keys.map(&:to_s)
          fields.select { |field| visible_ids.include?(field[:id]) || mapped_field_ids.include?(field[:id]) }
        end

        def visible_field_ids_for_table(table)
          view_id = import_configuration.airtable_view_id
          return [] if view_id.blank?

          view = table.fetch(:views, []).find { |item| item[:id] == view_id }
          view&.fetch(:visible_field_ids, []) || []
        end

        helper_method :proposal_field_options

        def proposal_field_options
          [
            [t("decidim.airtable.admin.import_configurations.show.proposal_fields.none"), ""],
            [t("decidim.airtable.admin.import_configurations.show.proposal_fields.title"), "title"],
            [t("decidim.airtable.admin.import_configurations.show.proposal_fields.body"), "body"],
            [t("decidim.airtable.admin.import_configurations.show.proposal_fields.address"), "address"],
            [t("decidim.airtable.admin.import_configurations.show.proposal_fields.latitude"), "latitude"],
            [t("decidim.airtable.admin.import_configurations.show.proposal_fields.longitude"), "longitude"],
            [t("decidim.airtable.admin.import_configurations.show.proposal_fields.reference"), "reference"],
            [t("decidim.airtable.admin.import_configurations.show.proposal_fields.cost"), "cost"],
            [t("decidim.airtable.admin.import_configurations.show.proposal_fields.state"), "state"]
          ]
        end

        helper_method :import_configuration
      end
    end
  end
end
