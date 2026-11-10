# frozen_string_literal: true

module Decidim
  module Airtable
    class Engine < ::Rails::Engine
      isolate_namespace Decidim::Airtable

      paths["db/migrate"] = nil
      paths["lib/tasks"] = nil
    end
  end
end
