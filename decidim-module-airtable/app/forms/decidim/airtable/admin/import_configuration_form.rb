# frozen_string_literal: true

module Decidim
  module Airtable
    module Admin
      class ImportConfigurationForm < Decidim::Form
        mimic :import_configuration

        attribute :airtable_base_id, String
        attribute :airtable_base_name, String
        attribute :airtable_table_id, String
        attribute :airtable_table_name, String
        attribute :airtable_view_id, String
        attribute :airtable_view_name, String
        attribute :decidim_component_id, Integer
        attribute :decidim_component_name, String
        attribute :decidim_participatory_space_name, String
        attribute :id, Integer
        attribute :active, Boolean, default: true
        attribute :organization, Decidim::Organization

        validates :airtable_base_id, :airtable_table_id, :decidim_component_id, :organization, presence: true
        validate :table_is_unique_for_organization_and_base
        validate :component_belongs_to_organization_and_is_proposals

        alias organization current_organization

        private

        def table_is_unique_for_organization_and_base
          return if organization.blank? || airtable_base_id.blank? || airtable_table_id.blank?

          query = Decidim::Airtable::ImportConfiguration
                  .where(decidim_organization_id: organization.id,
                         airtable_base_id: airtable_base_id,
                         airtable_table_id: airtable_table_id)
          query = query.where.not(id:) if id.present?
          exists = query.exists?

          return unless exists

          errors.add(:airtable_table_id, :already_configured_for_organization_and_base)
        end

        def component_belongs_to_organization_and_is_proposals
          return if organization.blank? || decidim_component_id.blank?

          component = Decidim::Component.find_by(id: decidim_component_id)
          if component.blank?
            errors.add(:decidim_component_id, :invalid)
            return
          end

          if component.manifest_name != "proposals"
            errors.add(:decidim_component_id, :invalid)
            return
          end

          return if component.participatory_space.respond_to?(:organization) && component.participatory_space.organization == organization

          errors.add(:decidim_component_id, :invalid)
        end
      end
    end
  end
end
