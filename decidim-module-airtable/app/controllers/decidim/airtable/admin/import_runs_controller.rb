# frozen_string_literal: true

module Decidim
  module Airtable
    module Admin
      class ImportRunsController < Decidim::Airtable::Admin::ApplicationController
        def show
          load_import_run
          enforce_permission_to :read, :import, import_configuration:
        end

        def cancel
          load_import_run
          enforce_permission_to :cancel, :import_runs, import_configuration:

          Decidim::Airtable::Admin::CancelImportRun.call(import_run:, organization: current_organization) do
            on(:ok) do
              redirect_to import_run_path(import_configuration, import_run), notice: t(".cancel_requested")
            end

            on(:invalid) do
              redirect_to import_run_path(import_configuration, import_run), alert: t(".cancel_unavailable")
            end
          end
        end

        private

        attr_reader :import_configuration, :import_run

        def load_import_run
          @import_configuration = Decidim::Airtable::ImportConfiguration
                                  .where(organization: current_organization)
                                  .find(params[:import_id])
          @import_run = @import_configuration.import_runs.find(params[:id])
        end
      end
    end
  end
end
