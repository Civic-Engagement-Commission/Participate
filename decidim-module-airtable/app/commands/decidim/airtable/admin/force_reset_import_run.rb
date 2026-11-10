# frozen_string_literal: true

module Decidim
  module Airtable
    module Admin
      class ForceResetImportRun < Decidim::Command
        def initialize(import_run:, organization:)
          @import_run = import_run
          @organization = organization
        end

        def call
          return broadcast(:invalid) unless import_run.import_configuration.organization == organization

          broadcast(import_run.force_reset! ? :ok : :invalid, import_run)
        end

        private

        attr_reader :import_run, :organization
      end
    end
  end
end
