# frozen_string_literal: true

module Decidim
  module Airtable
    module Admin
      class ImportConfigurationForm < Decidim::Form
        mimic :import_configuration

        attribute :airtable_base_id, String
        attribute :airtable_table_id, String
        attribute :airtable_view_id, String
        attribute :active, Boolean, default: true
        attribute :organization, Decidim::Organization

        validates :airtable_base_id, :airtable_table_id, :organization, presence: true
        validate :table_is_unique_for_organization_and_base

        alias organization current_organization

        private

        def table_is_unique_for_organization_and_base
          return if organization.blank? || airtable_base_id.blank? || airtable_table_id.blank?

          exists = Decidim::Airtable::ImportConfiguration
                   .where(decidim_organization_id: organization.id,
                          airtable_base_id: airtable_base_id,
                          airtable_table_id: airtable_table_id)
                   .exists?

          return unless exists

          errors.add(:airtable_table_id, :already_configured_for_organization_and_base)
        end
      end
    end
  end
end
