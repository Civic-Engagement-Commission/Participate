# frozen_string_literal: true

require "omniauth/strategies/nyc"

# Register NYC.ID (SAML) as a Decidim omniauth provider.
# Configuration values come from ENV vars. `setup_provider_proc` resolves
# per-organization settings against this hash at runtime.
Decidim.omniauth_providers[:nyc] = {
  enabled: ENV["OMNIAUTH_NYC_PROVIDER_NAME"].present?,
  icon_path: ENV["OMNIAUTH_NYC_ICON_PATH"],
  provider_name: ENV["OMNIAUTH_NYC_PROVIDER_NAME"],
  idp_cert_fingerprint: ENV["OMNIAUTH_NYC_CERT_FINGERPRINT"],
  idp_cert: ENV["OMNIAUTH_NYC_CERT"],
  idp_key: ENV["OMNIAUTH_NYC_KEY"],
  issuer: ENV["OMNIAUTH_NYC_ISSUER"],
  authn_context: ENV["OMNIAUTH_NYC_AUTHN_CONTEXT"],
  assertion_consumer_service_url: ENV["OMNIAUTH_NYC_CALLBACK"],
  idp_sso_target_callback_origin: ENV["OMNIAUTH_NYC_SSO_CALLBACK_ORIGIN"],
  idp_sso_target_url: ENV["OMNIAUTH_NYC_SSO_URL"],
  idp_slo_target_url: ENV["OMNIAUTH_NYC_SLO_URL"],
  sign_in_button_text: ENV["SIGN_IN_BUTTON_TEXT"],
  sign_up_button_url: ENV["SIGN_UP_BUTTON_NYID_URL"],
  sign_up_button_sp_name: ENV["SIGN_UP_BUTTON_SP_NAME"],
  sign_up_button_target: ENV["SIGN_UP_BUTTON_TARGET"],
  sign_up_button_text: ENV["SIGN_UP_BUTTON_TEXT"]
}

if Decidim.omniauth_providers.dig(:nyc, :enabled)
  Rails.application.config.middleware.use OmniAuth::Builder do
    OmniAuth.config.logger = Rails.logger

    provider(
      OmniAuth::Strategies::NYC,
      setup: setup_provider_proc(:nyc,
                                 icon_path: :icon_path,
                                 provider_name: :provider_name,
                                 idp_cert_fingerprint: :idp_cert_fingerprint,
                                 idp_cert: :idp_cert,
                                 certificate: :idp_cert,
                                 private_key: :idp_key,
                                 issuer: :issuer,
                                 authn_context: :authn_context,
                                 assertion_consumer_service_url: :assertion_consumer_service_url,
                                 idp_sso_target_callback_origin: :idp_sso_target_callback_origin,
                                 idp_sso_target_url: :idp_sso_target_url,
                                 idp_slo_target_url: :idp_slo_target_url)
    )
  end
end
