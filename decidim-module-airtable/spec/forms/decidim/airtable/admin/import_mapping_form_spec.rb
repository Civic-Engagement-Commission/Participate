# frozen_string_literal: true

require_relative "../../../../rails_helper"

describe Decidim::Airtable::Admin::ImportMappingForm do
  subject(:form) { described_class.from_params(params) }

  let(:params) do
    {
      field_mappings:,
      airtable_fields:
    }
  end

  let(:airtable_fields) do
    [
      { id: "fldAttachment", name: "Photos", type: "multipleAttachments" },
      { id: "fldText", name: "Summary", type: "singleLineText" },
      { id: "fldDate", name: "Published", type: "dateTime" }
    ]
  end

  describe "#normalized_field_mappings" do
    let(:field_mappings) do
      {
        fldAttachment: "attachments",
        fldText: "",
        fldDate: nil,
        fldTitle: "title"
      }
    end

    it "stringifies keys and removes blank mappings" do
      expect(form.normalized_field_mappings).to eq(
        "fldAttachment" => "attachments",
        "fldTitle" => "title"
      )
    end
  end

  describe "validations" do
    context "when writeback targets are mapped more than once" do
      let(:field_mappings) do
        {
          fldAttachment: "writeback_proposal_id",
          fldText: "writeback_proposal_id"
        }
      end

      it "is invalid" do
        expect(form).to be_invalid
        expect(form.errors[:field_mappings].join).to include("Write Decidim proposal ID can only be mapped once")
      end
    end

    context "when attachments target uses non-file field" do
      let(:field_mappings) { { fldText: "attachments" } }

      it "is invalid" do
        expect(form).to be_invalid
        expect(form.errors[:field_mappings].join).to include("must be an attachment field")
      end
    end

    context "when published_at uses non-date field" do
      let(:field_mappings) { { fldText: "published_at" } }

      it "is invalid" do
        expect(form).to be_invalid
        expect(form.errors[:field_mappings].join).to include("must be a date/datetime field")
      end
    end

    context "when mappings follow type constraints" do
      let(:field_mappings) do
        {
          fldAttachment: "attachments",
          fldDate: "published_at",
          fldText: "writeback_proposal_id"
        }
      end

      it "is valid" do
        expect(form).to be_valid
      end
    end
  end
end
