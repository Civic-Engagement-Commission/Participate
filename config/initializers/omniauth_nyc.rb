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
  idp_cert_fingerprint_algorithm: ENV.fetch("OMNIAUTH_NYC_CERT_FINGERPRINT_ALGORITHM", XMLSecurity::Document::SHA256),
  sp_cert: ENV.fetch("OMNIAUTH_NYC_CERT", nil),
  sp_key: ENV.fetch("OMNIAUTH_NYC_KEY", nil),
  sp_entity_id: ENV.fetch("OMNIAUTH_NYC_SP_ENTITY_ID", "https://www.participate.nyc.gov/users"),
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
  nyc_setup_proc = lambda do |env|
    request = Rack::Request.new(env)
    organization = Decidim::Organization.find_by(host: request.host)
    provider_config = organization&.enabled_omniauth_providers&.dig(:nyc) || organization&.enabled_omniauth_providers&.dig("nyc") || {}
    provider_config = provider_config.with_indifferent_access

    strategy_options = env["omniauth.strategy"].options

    strategy_options[:icon_path] = provider_config[:icon_path]
    strategy_options[:provider_name] = provider_config[:provider_name]
    strategy_options[:idp_cert] = provider_config[:idp_cert]
    strategy_options[:certificate] = provider_config[:sp_cert]
    strategy_options[:private_key] = provider_config[:sp_key]
    strategy_options[:sp_entity_id] = provider_config[:sp_entity_id]
    strategy_options[:authn_context] = provider_config[:authn_context]
    strategy_options[:assertion_consumer_service_url] = provider_config[:assertion_consumer_service_url]
    strategy_options[:idp_sso_target_callback_origin] = provider_config[:idp_sso_target_callback_origin]
    strategy_options[:idp_sso_target_url] = provider_config[:idp_sso_target_url]
    strategy_options[:idp_slo_target_url] = provider_config[:idp_slo_target_url]
    strategy_options[:idp_cert_fingerprint] = provider_config[:idp_cert_fingerprint]
    strategy_options[:idp_cert_fingerprint_algorithm] = provider_config[:idp_cert_fingerprint_algorithm].presence || XMLSecurity::Document::SHA256
  end

  Rails.application.config.middleware.use OmniAuth::Builder do
    OmniAuth.config.logger = Rails.logger

    provider(
      OmniAuth::Strategies::NYC,
      setup: nyc_setup_proc
    )
  end
end
