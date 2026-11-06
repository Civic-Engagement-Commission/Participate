# frozen_string_literal: true

require_relative "../../../rails_helper"

describe Decidim::Airtable::ProposalDataMapper do
  let(:organization) { create(:organization, default_locale: "en", available_locales: [:en, :es]) }
  let(:participatory_process) { create(:participatory_process, organization:) }
  let(:component) { create(:component, participatory_space: participatory_process, manifest_name: "proposals") }
  let(:import_configuration) do
    Decidim::Airtable::ImportConfiguration.create!(
      organization:,
      airtable_base_id: "appBase123",
      airtable_table_id: "tblIdeas123",
      settings: {
        "proposal_field_mappings" => {
          "fldTitle" => "title",
          "fldBody" => "body",
          "fldLatitude" => "latitude",
          "fldCost" => "cost",
          "fldCreatedAt" => "created_at",
          "fldAuthor" => "authors_by_email"
        },
        "proposal_field_mappings_snapshot" => {
          "fldAuthor" => { "kind" => "authors", "lookup_by" => "email" }
        }
      },
      active: true
    )
  end
  let(:mapper) { described_class.new(import_configuration:, component:) }

  it "maps standard fields into Decidim import data and preserves auxiliary mappings" do
    result = mapper.map(
      id: "rec001",
      created_at: "2026-11-05T12:00:00.000Z",
      fields: {
        "fldTitle" => "Community garden",
        "fldBody" => "Create a garden.",
        "fldLatitude" => "40.7128",
        "fldCost" => "125.50",
        "fldCreatedAt" => "2026-10-30T09:00:00.000Z",
        "fldAuthor" => "person@example.org"
      }
    )

    expect(result[:airtable_record_id]).to eq("rec001")
    expect(result[:proposal_data]).to include(
      :component => component,
      :"title/en" => "Community garden",
      :"body/en" => "Create a garden.",
      :latitude => 40.7128,
      :cost => BigDecimal("125.50"),
      :created_at => Time.zone.parse("2026-10-30T09:00:00.000Z")
    )
    expect(result[:auxiliary_mappings]).to contain_exactly(
      :airtable_field_id => "fldAuthor",
      :mapping => "authors_by_email",
      :metadata => { "kind" => "authors", "lookup_by" => "email" },
      :value => "person@example.org"
    )
  end

  it "omits unmapped and blank Airtable values" do
    result = mapper.map(id: "rec001", fields: { "fldTitle" => "", "fldUnknown" => "ignored" })

    expect(result[:proposal_data]).to eq(component: component)
    expect(result[:auxiliary_mappings]).to be_empty
  end
end
