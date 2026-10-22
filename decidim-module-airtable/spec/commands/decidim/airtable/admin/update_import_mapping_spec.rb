# frozen_string_literal: true

require "rails_helper"

describe Decidim::Airtable::Admin::UpdateImportMapping do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :confirmed, :admin, organization:) }
  let(:import_configuration) do
    Decidim::Airtable::ImportConfiguration.create!(
      organization:,
      airtable_base_id: "appBase123",
      airtable_table_id: "tblIdeas123",
      airtable_view_id: "viwOpen",
      settings: {
        "airtable_base_name" => "Community Ideas",
        "existing_key" => "preserved"
      },
      active: true
    )
  end

  let(:airtable_fields) do
    [
      { id: "fldDate", name: "Published", type: "dateTime" },
      { id: "fldAttachment", name: "Photos", type: "multipleAttachments" },
      { id: "fldAuthor", name: "Author", type: "singleLineText" },
      { id: "fldWriteback", name: "Proposal ID", type: "singleLineText" }
    ]
  end

  let(:form) do
    Decidim::Airtable::Admin::ImportMappingForm.from_params(
      field_mappings: {
        fldDate: "published_at",
        fldAttachment: "attachments",
        fldAuthor: "authors_by_email",
        fldWriteback: "writeback_proposal_id"
      },
      airtable_fields:
    )
  end

  before do
    allow(form).to receive(:current_user).and_return(user)
  end

  it "updates mapping settings and stores snapshot metadata" do
    result = nil

    described_class.call(form, import_configuration) do
      on(:ok) { |updated_configuration| result = updated_configuration }
      on(:invalid) { raise "expected command to be valid" }
    end

    import_configuration.reload

    expect(result).to eq(import_configuration)
    expect(import_configuration.settings["existing_key"]).to eq("preserved")
    expect(import_configuration.settings["proposal_field_mappings"]).to include(
      "fldDate" => "published_at",
      "fldAttachment" => "attachments"
    )

    snapshot = import_configuration.settings["proposal_field_mappings_snapshot"]
    expect(snapshot["fldWriteback"]).to include(
      "kind" => "writeback",
      "target" => "airtable",
      "attribute" => "proposal_id"
    )
    expect(snapshot["fldAuthor"]).to include(
      "kind" => "authors",
      "lookup_by" => "email"
    )
  end

  context "when form is invalid" do
    let(:form) do
      Decidim::Airtable::Admin::ImportMappingForm.from_params(
        field_mappings: {
          fldDate: "writeback_proposal_id",
          fldAttachment: "writeback_proposal_id"
        },
        airtable_fields:
      )
    end

    before do
      allow(form).to receive(:current_user).and_return(user)
    end

    it "broadcasts invalid and does not update settings" do
      original_settings = import_configuration.settings.deep_dup

      described_class.call(form, import_configuration) do
        on(:ok) { raise "expected command to be invalid" }
        on(:invalid) { nil }
      end

      expect(import_configuration.reload.settings).to eq(original_settings)
      expect(form.errors[:field_mappings]).to be_present
    end
  end
end
