# frozen_string_literal: true

module Decidim
  module Airtable
    module Admin
      class ApplicationController < Decidim::Admin::ApplicationController
        layout "decidim/airtable/admin/application"

        register_permissions(::Decidim::Airtable::Admin::ApplicationController,
                             ::Decidim::Airtable::Admin::Permissions,
                             ::Decidim::Admin::Permissions)

        def permission_class_chain
          ::Decidim.permissions_registry.chain_for(::Decidim::Airtable::Admin::ApplicationController)
        end
      end
    end
  end
end
