# frozen_string_literal: true

require_relative "../../../rails_helper"

describe Decidim::Airtable::ImportRecord do
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

  describe "validations" do
    subject(:import_record) do
      described_class.new(
        import_configuration:,
        organization:,
        airtable_record_id: "rec001",
        status: "pending"
      )
    end

    it "is valid with required fields" do
      expect(import_record).to be_valid
    end

    it "requires airtable_record_id" do
      import_record.airtable_record_id = nil

      expect(import_record).to be_invalid
      expect(import_record.errors[:airtable_record_id]).to be_present
    end

    it "enforces uniqueness of airtable_record_id per import configuration" do
      described_class.create!(
        import_configuration:,
        organization:,
        airtable_record_id: "rec001",
        status: "pending"
      )

      expect(import_record).to be_invalid
      expect(import_record.errors[:airtable_record_id]).to be_present
    end

    it "allows same airtable_record_id in another import configuration" do
      other_configuration = Decidim::Airtable::ImportConfiguration.create!(
        organization:,
        airtable_base_id: "appBase123",
        airtable_table_id: "tblOther123",
        airtable_view_id: "viwOpen",
        settings: {},
        active: true
      )

      described_class.create!(
        import_configuration:,
        organization:,
        airtable_record_id: "rec001",
        status: "pending"
      )

      other_record = described_class.new(
        import_configuration: other_configuration,
        organization:,
        airtable_record_id: "rec001",
        status: "pending"
      )

      expect(other_record).to be_valid
    end

    it "enforces uniqueness of external_identifier per import configuration when present" do
      described_class.create!(
        import_configuration:,
        organization:,
        airtable_record_id: "rec001",
        external_identifier: "ext-100",
        status: "pending"
      )

      duplicate = described_class.new(
        import_configuration:,
        organization:,
        airtable_record_id: "rec002",
        external_identifier: "ext-100",
        status: "pending"
      )

      expect(duplicate).to be_invalid
      expect(duplicate.errors[:external_identifier]).to be_present
    end
  end

  describe "status enum" do
    it "supports expected statuses" do
      expect(described_class.statuses.keys).to include("pending", "synced", "failed", "skipped")
    end
  end
end
