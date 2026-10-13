# frozen_string_literal: true

module Decidim
  module Airtable
    module Admin
      class ImportsController < Decidim::Airtable::Admin::ApplicationController
        def index; end

        def show
          @import_id = params[:id]
        end
      end
    end
  end
end
