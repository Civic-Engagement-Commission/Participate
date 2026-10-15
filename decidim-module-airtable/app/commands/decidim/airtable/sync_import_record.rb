# frozen_string_literal: true

module Decidim
  module Airtable
    class SyncImportRecord < Decidim::Command
      def initialize(**params)
        @import_configuration = params.fetch(:import_configuration)
        @organization = params.fetch(:organization)
        @airtable_record_id = params.fetch(:airtable_record_id)
        @proposal = params[:proposal]
        @external_identifier = params[:external_identifier]
        @row_checksum = params[:row_checksum]
        @metadata = params[:metadata] || {}
      end

      def call
        record = find_or_initialize_record
        record.assign_attributes(attributes)
        record.save!

        broadcast(:ok, record)
      rescue ActiveRecord::RecordInvalid
        broadcast(:invalid, record)
      end

      private

      attr_reader :import_configuration, :organization, :airtable_record_id, :proposal, :external_identifier, :row_checksum, :metadata

      def find_or_initialize_record
        record = record_by_airtable_id
        record ||= record_by_external_identifier
        record ||= Decidim::Airtable::ImportRecord.new(base_attributes)
        record
      end

      def record_by_airtable_id
        Decidim::Airtable::ImportRecord.find_by(
          decidim_airtable_import_configuration_id: import_configuration.id,
          airtable_record_id:
        )
      end

      def record_by_external_identifier
        return if external_identifier.blank?

        Decidim::Airtable::ImportRecord.find_by(
          decidim_airtable_import_configuration_id: import_configuration.id,
          external_identifier:
        )
      end

      def base_attributes
        {
          decidim_airtable_import_configuration_id: import_configuration.id,
          decidim_organization_id: organization.id,
          airtable_record_id:
        }
      end

      def attributes
        {
          decidim_organization_id: organization.id,
          airtable_record_id:,
          decidim_proposal_id: proposal&.id,
          external_identifier: external_identifier.presence,
          row_checksum: row_checksum.presence,
          metadata:,
          status: "synced",
          last_error: nil,
          last_synced_at: Time.current
        }
      end
    end
  end
end
