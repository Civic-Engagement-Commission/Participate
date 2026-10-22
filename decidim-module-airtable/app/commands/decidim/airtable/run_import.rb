# frozen_string_literal: true

module Decidim
  module Airtable
    class RunImport < Decidim::Command
      def initialize(import_configuration:)
        @import_configuration = import_configuration
      end

      def call
        return broadcast(:invalid) unless import_configuration.active?

        # Placeholder pipeline: row fetch/mapping/proposal upsert is implemented next.
        # Keeping this command as the import entrypoint allows admin-triggered and scheduled runs.
        broadcast(:ok, imported_count: 0, updated_count: 0, skipped_count: 0)
      end

      private

      attr_reader :import_configuration
    end
  end
end
