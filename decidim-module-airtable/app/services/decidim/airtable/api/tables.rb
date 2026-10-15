# frozen_string_literal: true

module Decidim
  module Airtable
    module Api
      class Tables
        def initialize(client: Client.new)
          @client = client
        end

        def for_base(base_id)
          response = @client.list_base_tables(base_id)
          (response.fetch("tables", [])).map do |table|
            {
              id: table["id"],
              name: table["name"],
              fields: table.fetch("fields", []).map do |field|
                {
                  id: field["id"],
                  name: field["name"],
                  type: field["type"]
                }
              end,
              views: table.fetch("views", []).map do |view|
                {
                  id: view["id"],
                  name: view["name"],
                  visible_field_ids: view.fetch("visibleFieldIds", [])
                }
              end
            }
          end
        rescue KeyError
          []
        end
      end
    end
  end
end
