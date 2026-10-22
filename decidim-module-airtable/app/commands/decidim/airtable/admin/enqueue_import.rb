# frozen_string_literal: true

module Decidim
  module Airtable
    module Admin
      class EnqueueImport < Decidim::Command
        def initialize(import_configuration, current_user)
          @import_configuration = import_configuration
          @current_user = current_user
        end

        def call
          return broadcast(:invalid) unless import_configuration.active?

          Decidim::Airtable::RunImportJob.perform_later(import_configuration.id, current_user.id)

          broadcast(:ok)
        end

        private

        attr_reader :import_configuration, :current_user
      end
    end
  end
end
