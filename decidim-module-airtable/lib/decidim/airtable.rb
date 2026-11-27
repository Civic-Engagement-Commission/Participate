# frozen_string_literal: true

require "decidim/airtable/engine"
require "decidim/airtable/admin"
require "decidim/airtable/admin_engine"

module Decidim
  module Airtable
    mattr_accessor :personal_token, default: Decidim::Env.new("AIRTABLE_PERSONAL_TOKEN", nil).value
    mattr_accessor :proxy_url, default: Decidim::Env.new("AIRTABLE_PROXY_URL", nil).value

    def self.ready?
      !personal_token.nil?
    end

    def self.proxy_uri
      return if proxy_url.blank?

      URI.parse(proxy_url)
    end
  end
end
