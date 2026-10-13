# frozen_string_literal: true

module Decidim
  module Airtable
    module Admin
      class ImportsController < Decidim::Airtable::Admin::ApplicationController
        before_action :load_available_bases, only: [:new, :create]

        def index
          @import_configurations = Decidim::Airtable::ImportConfiguration
                                   .where(organization: current_organization)
                                   .order(created_at: :desc)
        end

        def new
          @import_configuration = Decidim::Airtable::ImportConfiguration.new(active: true)
        end

        def create
          @import_configuration = Decidim::Airtable::ImportConfiguration.new(import_configuration_params)
          @import_configuration.organization = current_organization

          if @import_configuration.save
            redirect_to imports_path, notice: t(".success")
          else
            flash.now[:alert] = t(".error")
            render :new, status: :unprocessable_entity
          end
        end

        private

        def import_configuration_params
          params.require(:import_configuration).permit(:airtable_base_id, :airtable_table_id, :airtable_view_id, :active)
        end

        def load_available_bases
          @available_bases = Decidim::Airtable::Api::Bases.new.all
          @bases_loading_error = nil
        rescue Decidim::Airtable::Api::Error
          @available_bases = []
          @bases_loading_error = t("decidim.airtable.admin.imports.new.bases_loading_error")
        end
      end
    end
  end
end
