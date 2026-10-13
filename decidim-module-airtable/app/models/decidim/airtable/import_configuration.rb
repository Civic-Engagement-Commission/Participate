# frozen_string_literal: true

module Decidim
  module Airtable
    class ImportConfiguration < ApplicationRecord
      belongs_to :organization,
                 class_name: "Decidim::Organization",
                 foreign_key: :decidim_organization_id,
                 inverse_of: false

      scope :active, -> { where(active: true) }

      validates :decidim_organization_id, :airtable_base_id, :airtable_table_id, presence: true
      validates :airtable_table_id,
                uniqueness: {
                  scope: [:decidim_organization_id, :airtable_base_id],
                  message: :already_configured_for_organization_and_base
                }
    end
  end
end
