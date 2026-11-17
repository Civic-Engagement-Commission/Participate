# frozen_string_literal: true

require "decidim/airtable/engine"
require "decidim/airtable/admin"
require "decidim/airtable/admin_engine"

module Decidim
  module Airtable
    include ActiveSupport::Configurable
    config_accessor :personal_token do
      ENV.fetch("AIRTABLE_PERSONAL_TOKEN", nil)
    end

    # Outbound HTTP proxy for Airtable API calls and attachment downloads,
    # e.g. "http://proxy.example.org:8080" or "http://user:pass@proxy.example.org:8080".
    # When blank, requests use the process-wide proxy environment (https_proxy, no_proxy) if any.
    config_accessor :proxy_url do
      ENV.fetch("AIRTABLE_PROXY_URL", nil)
    end

    def self.ready?
      !personal_token.nil?
    end

    def self.proxy_uri
      return if proxy_url.blank?

      URI.parse(proxy_url)
    end
  end
end
