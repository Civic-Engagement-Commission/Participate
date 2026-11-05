# frozen_string_literal: true

module Decidim
  module Airtable
    module Api
      class Records
        def initialize(client: Client.new)
          @client = client
        end

        def all(base_id:, table_id:, view_id: nil)
          offset = nil
          records = []

          loop do
            response = @client.list_records(base_id:, table_id:, view_id:, offset:)
            validate_response!(response)
            records.concat(response.fetch("records").map { |record| normalize_record(record) })
            offset = response.fetch("offset", nil)
            break if offset.blank?
          end

          records
        end

        private

        def validate_response!(response)
          raise Error, "Invalid Airtable records response: records must be an array" unless response.is_a?(Hash) && response["records"].is_a?(Array)
        end

        def normalize_record(record)
          unless record.is_a?(Hash) && record["id"].present? && (record["fields"].nil? || record["fields"].is_a?(Hash))
            raise Error, "Invalid Airtable records response: each record must include an id and fields object"
          end

          {
            id: record.fetch("id"),
            fields: record["fields"] || {},
            created_at: record["createdTime"]
          }
        end
      end
    end
  end
end
