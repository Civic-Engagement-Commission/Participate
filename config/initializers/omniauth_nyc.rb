# frozen_string_literal: true

require "omniauth/strategies/nyc"

# Register NYC.ID (SAML) as a Decidim omniauth provider.
# Configuration values come from ENV vars. `setup_provider_proc` resolves
# per-organization settings against this hash at runtime.
Decidim.omniauth_providers[:nyc] = {
  enabled: ENV["OMNIAUTH_NYC_PROVIDER_NAME"].present?,
  icon_path: ENV.fetch("OMNIAUTH_NYC_ICON_PATH", "media/images/nyc-logo.svg"),
  provider_name: ENV.fetch("OMNIAUTH_NYC_PROVIDER_NAME", nil),
  idp_cert_fingerprint: ENV.fetch("OMNIAUTH_NYC_CERT_FINGERPRINT", nil),
  idp_cert: ENV.fetch("OMNIAUTH_NYC_CERT", nil),
  idp_key: ENV.fetch("OMNIAUTH_NYC_KEY", nil),
  issuer: ENV.fetch("OMNIAUTH_NYC_ISSUER", "https://www.participate.nyc.gov/users"),
  authn_context: ENV.fetch("OMNIAUTH_NYC_AUTHN_CONTEXT", nil),
  assertion_consumer_service_url: ENV.fetch("OMNIAUTH_NYC_CALLBACK", "https://www.participate.nyc.gov/users/auth/nyc/callback"),
  idp_sso_target_callback_origin: ENV.fetch("OMNIAUTH_NYC_SSO_CALLBACK_ORIGIN", nil),
  idp_sso_target_url: ENV.fetch("OMNIAUTH_NYC_SSO_URL", nil),
  idp_slo_target_url: ENV.fetch("OMNIAUTH_NYC_SLO_URL", nil),
  sign_in_button_text: ENV.fetch("SIGN_IN_BUTTON_TEXT", "Sign in with NYC.ID"),
  sign_up_button_url: ENV.fetch("SIGN_UP_BUTTON_NYID_URL", "https://www1.nyc.gov/account/register.htm"),
  sign_up_button_sp_name: ENV.fetch("SIGN_UP_BUTTON_SP_NAME", "www.participate.nyc.gov"),
  sign_up_button_target: ENV.fetch("SIGN_UP_BUTTON_TARGET", "https://www.participate.nyc.gov/sign_in_redirect/nyc"),
  sign_up_button_text: ENV.fetch("SIGN_UP_BUTTON_TEXT", "Create NYC.ID account")
}

if Decidim.omniauth_providers.dig(:nyc, :enabled) || Rails.env.test?
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
