# frozen_string_literal: true

require_relative "../../../rails_helper"
require "decidim/proposals/test/factories"

describe Decidim::Airtable::ProcessImportRow do
  let(:organization) { create(:organization, available_locales: [:en]) }
  let(:current_user) { create(:user, :confirmed, :admin, organization:) }
  let(:participatory_process) { create(:participatory_process, organization:) }
  let(:component) { create(:proposal_component, participatory_space: participatory_process) }
  let(:import_configuration) do
    Decidim::Airtable::ImportConfiguration.create!(
      organization:,
      airtable_base_id: "appBase123",
      airtable_table_id: "tblIdeas123",
      settings: {},
      active: true
    )
  end
  let(:mapped_record) do
    {
      airtable_record_id: "rec001",
      row_checksum: "checksum-1",
      proposal_data: {
        component:,
        "title/en": "Imported proposal",
        "body/en": "Proposal details"
      },
      auxiliary_mappings: []
    }
  end

  def process_row(record = mapped_record)
    outcome = nil
    result = nil

    described_class.call(import_configuration:, current_user:, mapped_record: record) do
      on(:ok) do |value|
        outcome = :ok
        result = value
      end
      on(:invalid) do |value|
        outcome = :invalid
        result = value
      end
    end

    [outcome, result]
  end

  it "creates a proposal and links a synced import record" do
    outcome, result = process_row

    expect(outcome).to eq(:ok)
    expect(result[:operation]).to eq(:created)
    expect(result[:proposal]).to be_persisted
    expect(result[:proposal].title["en"]).to eq("Imported proposal")

    tracking = Decidim::Airtable::ImportRecord.find_by!(import_configuration:, airtable_record_id: "rec001")
    expect(tracking.proposal).to eq(result[:proposal])
    expect(tracking.status).to eq("synced")
    expect(tracking.row_checksum).to eq("checksum-1")
  end

  it "updates the tracked proposal instead of creating a duplicate" do
    _outcome, first_result = process_row
    updated_record = mapped_record.deep_merge(proposal_data: { :"title/en" => "Updated proposal" })

    expect do
      outcome, result = process_row(updated_record)
      expect(outcome).to eq(:ok)
      expect(result[:operation]).to eq(:updated)
      expect(result[:proposal]).to eq(first_result[:proposal])
    end.not_to change(Decidim::Proposals::Proposal, :count)

    expect(first_result[:proposal].reload.title["en"]).to eq("Updated proposal")
    expect(Decidim::Airtable::ImportRecord.where(import_configuration:, airtable_record_id: "rec001").count).to eq(1)
  end

  it "resolves mapped authors and taxonomy values" do
    author = create(:user, organization:, email: "coauthor@example.org")
    root_taxonomy = create(:taxonomy, organization:, name: { en: "Topic" })
    taxonomy = create(:taxonomy, parent: root_taxonomy, organization:, name: { en: "Parks" })
    row = mapped_record.deep_merge(
      auxiliary_mappings: [
        {
          mapping: "authors_by_email",
          value: "coauthor@example.org",
          metadata: { "kind" => "authors", "lookup_by" => "email" }
        },
        {
          mapping: "taxonomy_root:#{root_taxonomy.id}",
          value: "Parks",
          metadata: { "kind" => "taxonomy_root", "taxonomy_id" => root_taxonomy.id }
        }
      ]
    )

    outcome, result = process_row(row)

    expect(outcome).to eq(:ok)
    expect(result[:proposal].authors).to include(author, organization)
    expect(result[:proposal].taxonomies).to contain_exactly(taxonomy)
  end

  it "records a failed status for unsupported mappings without creating a proposal" do
    unsupported_record = mapped_record.deep_merge(
      auxiliary_mappings: [
        { mapping: "attachments", value: [{ "url" => "https://example.org/file.pdf" }], metadata: {} }
      ]
    )

    expect do
      outcome, result = process_row(unsupported_record)
      expect(outcome).to eq(:invalid)
      expect(result[:error]).to match(/Unsupported configured mapping/)
    end.not_to change(Decidim::Proposals::Proposal, :count)

    tracking = Decidim::Airtable::ImportRecord.find_by!(import_configuration:, airtable_record_id: "rec001")
    expect(tracking.status).to eq("failed")
    expect(tracking.last_error).to match(/attachments/)
  end
end
