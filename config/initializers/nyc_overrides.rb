# frozen_string_literal: true

# NYC-specific Decidim customizations.
# Standard settings are read directly from ENV by decidim-core via
# Decidim::Env (see decidim-core/lib/decidim/core.rb), so they do not need
# duplicating here. Only NYC overrides live in this file.

# Fallback icon for the NYC.ID omniauth button. Used when
# `OMNIAUTH_NYC_ICON_PATH` is not set (dev/test, or prod without an explicit
# icon asset). External icon from ENV always takes precedence in `oauth_icon`.
Decidim.icons.register(name: "nyc-fill", icon: "government-fill", description: "NYC.ID omniauth provider icon", category: "system", engine: :core)
Rails.application.config.to_prepare do
  # Wire concern-based overrides into Decidim core classes on every code reload
  # (moved here from the former decidim_overrides.rb to keep overrides in one place).
  Decidim::Devise::OmniauthRegistrationsController.include(Decidim::Devise::OmniauthRegistrationsControllerOverride)
  Decidim::Proposals::Import::ProposalCreator.include(Decidim::Proposals::Import::ProposalCreatorOverride)
end

Decidim.configure do |config|
  # Cookie consent categories — extended to cover third-party services NYC
  # embeds (Airtable, Google Maps, YouTube nocookie).
  config.consent_categories = [
    {
      slug: "essential",
      mandatory: true,
      items: [
        { type: "cookie", name: "_session_id" },
        { type: "cookie", name: Decidim.consent_cookie_name },
        { type: "cookie", name: "youtube-nocookie" },
        { type: "cookie", name: "google-maps" },
        { type: "cookie", name: "airtable" }
      ]
    }
  ]

  # Extra CSP rules for third-party hosts used by NYC customizations
  # (Google Translate widget loaded from gstatic/google/googleapis).
  config.content_security_policies_extra = {
    "connect-src" => %w(*.gstatic.com *.google.com *.googleapis.com),
    "img-src" => %w(*.gstatic.com *.google.com *.googleapis.com),
    "script-src" => %w(*.gstatic.com *.google.com *.googleapis.com),
    "style-src" => %w(*.gstatic.com *.google.com *.googleapis.com)
  }
end
