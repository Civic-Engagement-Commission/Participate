# frozen_string_literal: true

module Decidim
  module Devise
    module OmniauthRegistrationsControllerOverride
      extend ActiveSupport::Concern

      included do
        skip_before_action :verify_authenticity_token, if: :saml_callback?

        private

        def saml_callback?
          custom_callback_origin = request.env["omniauth.strategy"]&.options&.[](:idp_sso_target_callback_origin)
          Rails.logger.debug { "OmniauthRegistrationsControllerOverride::saml_callback? Custom callback origin: #{custom_callback_origin}" }
          result = request.path.end_with?("/callback") && custom_callback_origin.present? && URI.parse(request.origin).host == custom_callback_origin
          Rails.logger.debug { "OmniauthRegistrationsControllerOverride::saml_callback? Result: #{result}" }

          Rails.logger.info "Skip authenticity token verification for authorized origin: #{custom_callback_origin}" if result
          result
        end
      end
    end
  end
end
