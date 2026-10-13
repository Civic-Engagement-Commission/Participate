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

    def self.ready?
      !personal_token.nil?
    end
  end
end
