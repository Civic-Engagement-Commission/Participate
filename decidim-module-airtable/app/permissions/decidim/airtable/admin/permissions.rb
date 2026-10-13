# frozen_string_literal: true

module Decidim
  module Airtable
    module Admin
      class Permissions < Decidim::DefaultPermissions
        def permissions
          return permission_action if permission_action.scope != :admin
          return permission_action unless user
          return permission_action if context[:current_organization] != user.organization
          return permission_action unless user.admin?

          case permission_action.subject
          when :imports
            allow! if [:index, :read].include?(permission_action.action)
          when :import
            allow! if [:read, :create, :update, :destroy].include?(permission_action.action)
          end

          permission_action
        end
      end
    end
  end
end
