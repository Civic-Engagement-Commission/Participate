# frozen_string_literal: true

module Decidim
  module Airtable
    module Api
      class Bases
        def initialize(client: Client.new)
          @client = client
        end

        def all
          offset = nil
          bases = []

          loop do
            response = @client.list_bases(offset:)
            bases.concat(response.fetch("bases", []))
            offset = response["offset"]
            break if offset.blank?
          end

          bases.map do |base|
            { id: base["id"], name: base["name"] }
          end
        rescue KeyError
          []
        end
      end
    end
  end
end
