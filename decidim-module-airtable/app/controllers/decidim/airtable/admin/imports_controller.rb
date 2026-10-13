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
          @form = form(Decidim::Airtable::Admin::ImportConfigurationForm).instance
        end

        def create
          @form = form(Decidim::Airtable::Admin::ImportConfigurationForm).from_params(params)

          Decidim::Airtable::Admin::CreateImportConfiguration.call(@form) do
            on(:ok) do
              redirect_to imports_path, notice: t(".success")
            end

            on(:invalid) do
              flash.now[:alert] = t(".error")
              render :new, status: :unprocessable_entity
            end
          end
        end

        private

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
