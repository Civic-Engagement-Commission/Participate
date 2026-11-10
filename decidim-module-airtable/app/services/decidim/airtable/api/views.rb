# frozen_string_literal: true

module Decidim
  module Airtable
    module Api
      class Views
        def initialize(tables: Tables.new)
          @tables = tables
        end

        def for_base_and_table(base_id, table_id)
          table = @tables.for_base(base_id).find { |item| item[:id] == table_id }
          return [] unless table

          table[:views]
        end
      end
    end
  end
end
