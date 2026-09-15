# frozen_string_literal: true

# NYC-specific Decidim customizations.
# Standard settings are read directly from ENV by decidim-core via
# Decidim::Env (see decidim-core/lib/decidim/core.rb), so they do not need
# duplicating here. Only NYC overrides live in this file.

# Fallback icon for the NYC.ID omniauth button. Used when
# `OMNIAUTH_NYC_ICON_PATH` is not set (dev/test, or prod without an explicit
# icon asset). External icon from ENV always takes precedence in `oauth_icon`.
Decidim.icons.register(name: "nyc-fill", icon: "government-fill", description: "NYC.ID omniauth provider icon", category: "system", engine: :core)

# Prevent cascading failures when S3 is inaccessible during error handling
# Handle at the AWS SDK object level to catch the waiter errors
if defined?(Aws::S3::Object)
  Aws::S3::Object.class_eval do
    def exists_with_error_handling
      exists_without_error_handling
    rescue Aws::S3::Errors::Forbidden, Aws::S3::Errors::ServiceError, Aws::Waiters::Errors::UnexpectedError => e
      Rails.logger.warn "S3 error during existence check: #{e.class} - #{e.message}"
      false
    end

    alias_method :exists_without_error_handling, :exists?
    alias_method :exists?, :exists_with_error_handling
  end
end

# Also handle at the view level as a fallback
if defined?(Decidim::MetaTagsHelper)
  Decidim::MetaTagsHelper.module_eval do
    def add_decidim_meta_tags_with_error_handling
      add_decidim_meta_tags_without_error_handling
    rescue Aws::S3::Errors::Forbidden, Aws::S3::Errors::ServiceError, Aws::Waiters::Errors::UnexpectedError => e
      Rails.logger.warn "S3 error during meta tags generation: #{e.class} - #{e.message}"
      # Return empty to prevent cascading failures
      ""
    end

    alias_method :add_decidim_meta_tags_without_error_handling, :add_decidim_meta_tags
    alias_method :add_decidim_meta_tags, :add_decidim_meta_tags_with_error_handling
  end
end

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
