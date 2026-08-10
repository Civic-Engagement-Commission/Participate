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
if defined?(Decidim::MetaImageUrlResolver)
  Decidim::MetaImageUrlResolver.class_eval do
    def resolve_with_error_handling
      resolve_without_error_handling
    rescue Aws::S3::Errors::Forbidden, Aws::S3::Errors::ServiceError => e
      Rails.logger.warn "S3 error during meta image resolution: #{e.class} - #{e.message}"
      nil
    end

    alias_method :resolve_without_error_handling, :resolve
    alias_method :resolve, :resolve_with_error_handling
  end
end

if defined?(Decidim::MetaTagsHelper)
  Decidim::MetaTagsHelper.module_eval do
    def resolve_meta_image_url_with_error_handling(*args)
      resolve_meta_image_url_without_error_handling(*args)
    rescue Aws::S3::Errors::Forbidden, Aws::S3::Errors::ServiceError => e
      Rails.logger.warn "S3 error during meta image resolution: #{e.class} - #{e.message}"
      nil
    end

    alias_method :resolve_meta_image_url_without_error_handling, :resolve_meta_image_url
    alias_method :resolve_meta_image_url, :resolve_meta_image_url_with_error_handling
  end
end

# Wrap ActiveStorage S3 service to handle errors gracefully
if defined?(ActiveStorage::Service::S3Service)
  ActiveStorage::Service::S3Service.class_eval do
    def exist_with_error_handling(key, **options)
      exist_without_error_handling(key, **options)
    rescue Aws::S3::Errors::Forbidden, Aws::S3::Errors::ServiceError => e
      Rails.logger.warn "S3 error during existence check: #{e.class} - #{e.message}"
      false
    end

    def url_with_error_handling(key, **options)
      url_without_error_handling(key, **options)
    rescue Aws::S3::Errors::Forbidden, Aws::S3::Errors::ServiceError => e
      Rails.logger.warn "S3 error during URL generation: #{e.class} - #{e.message}"
      nil
    end

    alias_method :exist_without_error_handling, :exist?
    alias_method :exist?, :exist_with_error_handling
    alias_method :url_without_error_handling, :url
    alias_method :url, :url_with_error_handling
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
