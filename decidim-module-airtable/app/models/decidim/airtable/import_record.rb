# frozen_string_literal: true

module Decidim
  module Airtable
    class ImportRecord < ApplicationRecord
      self.table_name = "decidim_airtable_import_records"

      belongs_to :import_configuration,
                 class_name: "Decidim::Airtable::ImportConfiguration",
                 foreign_key: :decidim_airtable_import_configuration_id,
                 inverse_of: :import_records
      belongs_to :organization,
                 class_name: "Decidim::Organization",
                 foreign_key: :decidim_organization_id,
                 inverse_of: false
      belongs_to :proposal,
                 class_name: "Decidim::Proposals::Proposal",
                 foreign_key: :decidim_proposal_id,
                 optional: true,
                 inverse_of: false

      enum :status, {
        pending: "pending",
        synced: "synced",
        failed: "failed",
        skipped: "skipped"
      }, prefix: true

      validates :airtable_record_id, presence: true
      validates :airtable_record_id,
                uniqueness: {
                  scope: :decidim_airtable_import_configuration_id
                }
      validates :external_identifier,
                uniqueness: {
                  scope: :decidim_airtable_import_configuration_id
                },
                allow_blank: true
      validates :status, presence: true
    end
  end
end
