# frozen_string_literal: true

module Decidim
  module ParticipatoryProcesses
    module ParticipatoryProcessesControllerOverride
      extend ActiveSupport::Concern

      included do
        private

        def default_date_filter
          "all"
        end
      end
    end
  end
end
