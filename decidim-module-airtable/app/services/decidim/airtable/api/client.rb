# frozen_string_literal: true

require "airrecord"

module Decidim
  module Airtable
    module Api
      class Error < StandardError; end

      class Client
        BASES_PATH = "/v0/meta/bases"

        def initialize(personal_token: Decidim::Airtable.personal_token)
          @personal_token = personal_token
        end

        def list_bases(offset: nil)
          raise Error, "Airtable personal token is missing" if @personal_token.blank?

          response = airrecord_client.connection.get(BASES_PATH) do |request|
            request.params["offset"] = offset if offset.present?
          end
          parsed_response = airrecord_client.parse(response.body)

          if response.success?
            parsed_response
          else
            airrecord_client.handle_error(response.status, parsed_response)
          end
        rescue Airrecord::Error => e
          raise Error, e.message
        end

        private

        def airrecord_client
          @airrecord_client ||= Airrecord::Client.new(@personal_token)
        end
      end
    end
  end
end
