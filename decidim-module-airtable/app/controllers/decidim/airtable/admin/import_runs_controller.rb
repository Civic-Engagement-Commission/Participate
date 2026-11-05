# frozen_string_literal: true

module Decidim
  module Airtable
    module Admin
      class ImportRunsController < Decidim::Airtable::Admin::ApplicationController
        def show
          @import_configuration = Decidim::Airtable::ImportConfiguration
                                  .where(organization: current_organization)
                                  .find(params[:import_id])
          enforce_permission_to :read, :import, import_configuration: @import_configuration
          @import_run = @import_configuration.import_runs.find(params[:id])
        end
      end
    end
  end
end
