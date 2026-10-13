# frozen_string_literal: true

module Decidim
  module Airtable
    module Admin
      class ApplicationController < Decidim::Admin::ApplicationController
        layout "decidim/airtable/admin/application"
      end
    end
  end
end
