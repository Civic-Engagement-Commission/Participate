# frozen_string_literal: true

module Decidim
  module Airtable
    module Admin
      class ImportsController < Decidim::Airtable::Admin::ApplicationController
        before_action :load_available_bases, only: [:new, :create, :edit, :update]
        before_action :import_configuration, only: [:edit, :update, :destroy]

        def index
          enforce_permission_to :read, :imports
          @import_configurations = Decidim::Airtable::ImportConfiguration
                                   .where(organization: current_organization)
                                   .order(created_at: :desc)
        end

        def new
          enforce_permission_to :create, :import
          @form = form(Decidim::Airtable::Admin::ImportConfigurationForm).instance
          prepare_new_form
        end

        def create
          enforce_permission_to :create, :import
          @form = form(Decidim::Airtable::Admin::ImportConfigurationForm).from_params(params)

          Decidim::Airtable::Admin::CreateImportConfiguration.call(@form) do
            on(:ok) do
              redirect_to imports_path, notice: t(".success")
            end

            on(:invalid) do
              flash.now[:alert] = t(".error")
              prepare_new_form
              render :new, status: :unprocessable_entity
            end
          end
        end

        def edit
          enforce_permission_to :update, :import, import_configuration:
          @form = form(Decidim::Airtable::Admin::ImportConfigurationForm).from_model(import_configuration)
          prepare_edit_form
          render :new
        end

        def update
          enforce_permission_to :update, :import, import_configuration:
          @form = form(Decidim::Airtable::Admin::ImportConfigurationForm).from_params(params)
          @form.id = import_configuration.id

          Decidim::Airtable::Admin::UpdateImportConfiguration.call(@form, import_configuration) do
            on(:ok) do
              redirect_to imports_path, notice: t(".success")
            end

            on(:invalid) do
              flash.now[:alert] = t(".error")
              prepare_edit_form
              render :new, status: :unprocessable_entity
            end
          end
        end

        def destroy
          enforce_permission_to :destroy, :import, import_configuration:
          Decidim::Commands::DestroyResource.call(import_configuration, current_user) do
            on(:ok) do
              redirect_to imports_path, notice: t(".success")
            end
          end
        end

        def table_options
          enforce_permission_to :read, :import
          tables = Decidim::Airtable::Api::Tables.new.for_base(params[:base_id])
          render json: tables.map { |table| { id: table[:id], name: table[:name] } }
        rescue Decidim::Airtable::Api::Error
          render json: [], status: :unprocessable_entity
        end

        def view_options
          enforce_permission_to :read, :import
          views = Decidim::Airtable::Api::Views.new.for_base_and_table(params[:base_id], params[:table_id])
          render json: views
        rescue Decidim::Airtable::Api::Error
          render json: [], status: :unprocessable_entity
        end

        private

        def import_configuration
          @import_configuration ||= Decidim::Airtable::ImportConfiguration
                                    .where(organization: current_organization)
                                    .find(params[:id])
        end

        def prepare_new_form
          @page_title = t("decidim.airtable.admin.imports.new.title")
          @submit_label = t("decidim.airtable.admin.imports.new.submit")
          @form_url = imports_path
          @form_method = :post
        end

        def prepare_edit_form
          @page_title = t("decidim.airtable.admin.imports.edit.title")
          @submit_label = t("decidim.airtable.admin.imports.edit.submit")
          @form_url = import_path(import_configuration)
          @form_method = :patch
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
