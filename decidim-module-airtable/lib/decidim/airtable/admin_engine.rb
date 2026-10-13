# frozen_string_literal: true

module Decidim
  module Airtable
    class AdminEngine < ::Rails::Engine
      isolate_namespace Decidim::Airtable::Admin

      paths["db/migrate"] = nil
      paths["lib/tasks"] = nil

      routes do
        resources :imports, only: [:index, :new, :create, :show, :edit, :update, :destroy] do
          collection do
            get :table_options
            get :view_options
          end
        end
      end

      initializer "decidim_admin_airtable.mount_routes" do
        Decidim::Core::Engine.routes do
          mount Decidim::Airtable::AdminEngine, at: "/admin/airtable", as: "decidim_admin_airtable"
        end
      end

      initializer "decidim_admin_airtable.admin_menu" do
        Decidim.menu :admin_menu do |menu|
          menu.add_item :airtable,
                        I18n.t("menu.airtable", scope: "decidim.airtable.admin"), decidim_admin_airtable.imports_path,
                        active: is_active_link?(decidim_admin_airtable.imports_path),
                        icon_name: "bar-chart-2-line"
        end
      end
    end
  end
end
