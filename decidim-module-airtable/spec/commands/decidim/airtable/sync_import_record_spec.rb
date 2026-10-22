# frozen_string_literal: true

require_relative "../../../rails_helper"
require "decidim/proposals/test/factories"

describe Decidim::Airtable::SyncImportRecord do
  let(:organization) { create(:organization) }
  let(:import_configuration) do
    Decidim::Airtable::ImportConfiguration.create!(
      organization:,
      airtable_base_id: "appBase123",
      airtable_table_id: "tblIdeas123",
      airtable_view_id: "viwOpen",
      settings: {},
      active: true
    )
  end

  let(:proposal) { create(:proposal) }

  describe ".call" do
    it "creates a new tracking record for a new airtable record" do
      record = nil

      described_class.call(
        import_configuration:,
        organization:,
        airtable_record_id: "rec001",
        external_identifier: "ext-1",
        proposal:,
        row_checksum: "abc123",
        metadata: { "source" => "airtable" }
      ) do
        on(:ok) { |result| record = result }
        on(:invalid) { raise "expected sync to be valid" }
      end

      expect(record).to be_present
      expect(record).to be_persisted
      expect(record.status).to eq("synced")
      expect(record.external_identifier).to eq("ext-1")
      expect(record.airtable_record_id).to eq("rec001")
      expect(record.decidim_proposal_id).to eq(proposal.id)
      expect(record.row_checksum).to eq("abc123")
    end

    it "updates existing record by airtable_record_id instead of duplicating" do
      existing = Decidim::Airtable::ImportRecord.create!(
        import_configuration:,
        organization:,
        airtable_record_id: "rec001",
        status: "pending"
      )

      expect do
        described_class.call(
          import_configuration:,
          organization:,
          airtable_record_id: "rec001",
          external_identifier: "ext-1",
          proposal:,
          row_checksum: "xyz"
        )
      end.not_to change(Decidim::Airtable::ImportRecord, :count)

      existing.reload
      expect(existing.status).to eq("synced")
      expect(existing.external_identifier).to eq("ext-1")
      expect(existing.decidim_proposal_id).to eq(proposal.id)
      expect(existing.row_checksum).to eq("xyz")
    end

    it "finds existing record by external_identifier as fallback" do
      existing = Decidim::Airtable::ImportRecord.create!(
        import_configuration:,
        organization:,
        airtable_record_id: "rec-old",
        external_identifier: "ext-1",
        status: "pending"
      )

      described_class.call(
        import_configuration:,
        organization:,
        airtable_record_id: "rec-new",
        external_identifier: "ext-1",
        proposal:
      )

      existing.reload
      expect(existing.airtable_record_id).to eq("rec-new")
      expect(existing.status).to eq("synced")
    end
  end
end
