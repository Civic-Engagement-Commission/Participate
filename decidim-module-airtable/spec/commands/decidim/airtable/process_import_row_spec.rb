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

  def process_row(record = mapped_record, **dependencies)
    outcome = nil
    result = nil

    described_class.call(import_configuration:, current_user:, mapped_record: record, **dependencies) do
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

  it "accepts string-keyed mapped rows when locating their tracking record" do
    outcome, result = process_row(mapped_record.deep_stringify_keys)

    expect(outcome).to eq(:ok)
    expect(result[:proposal]).to be_persisted
    expect(Decidim::Airtable::ImportRecord.find_by!(import_configuration:, airtable_record_id: "rec001").proposal).to eq(result[:proposal])
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

  it "links an untracked Airtable row to the proposal ID already written back to Airtable" do
    proposal = create(
      :proposal,
      component:,
      title: { en: "Old title" },
      body: { en: "Old body" }
    )
    row = mapped_record.deep_merge(
      auxiliary_mappings: [
        {
          airtable_field_id: "fldProposalId",
          mapping: "writeback_proposal_id",
          metadata: { "kind" => "writeback", "attribute" => "proposal_id" },
          value: proposal.id.to_s
        }
      ]
    )
    airtable_client = instance_double(Decidim::Airtable::Api::Client)
    allow(airtable_client).to receive(:update_record)

    outcome, result = process_row(row, airtable_client:)

    expect(outcome).to eq(:ok)
    expect(result[:operation]).to eq(:updated)
    expect(result[:proposal]).to eq(proposal)
    expect(proposal.reload.title["en"]).to eq("Imported proposal")
    expect(Decidim::Airtable::ImportRecord.find_by!(import_configuration:, airtable_record_id: "rec001").proposal).to eq(proposal)
  end

  it "links an untracked Airtable row to an existing proposal by mapped reference" do
    proposal = create(
      :proposal,
      component:,
      reference: "NYC-EXT-100",
      title: { en: "Old title" },
      body: { en: "Old body" }
    )
    row = mapped_record.deep_merge(proposal_data: { reference: "NYC-EXT-100" })

    outcome, result = process_row(row)

    expect(outcome).to eq(:ok)
    expect(result[:operation]).to eq(:updated)
    expect(result[:proposal]).to eq(proposal)
    expect(Decidim::Airtable::ImportRecord.find_by!(import_configuration:, airtable_record_id: "rec001").proposal).to eq(proposal)
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

  it "applies mapped Awesome custom fields" do
    mapping = {
      mapping: "awesome_custom:public:project_name",
      value: "Community garden",
      metadata: { "kind" => "awesome_custom", "name" => "project_name", "visibility" => "public" }
    }
    mapped_custom_record = mapped_record.deep_merge(auxiliary_mappings: [mapping])
    updater = instance_double(Decidim::Airtable::ProposalCustomFieldsUpdater)
    allow(Decidim::Airtable::ProposalCustomFieldsUpdater).to receive(:new).and_return(updater)
    allow(updater).to receive(:apply)

    outcome, result = process_row(mapped_custom_record)

    expect(outcome).to eq(:ok)
    expect(updater).to have_received(:apply).with(result[:proposal], [mapping])
  end

  it "creates and replaces Airtable attachments without duplicating them" do
    attachment_mapping = {
      airtable_field_id: "fldAttachment",
      mapping: "attachments",
      metadata: { "kind" => "attachments" },
      value: [{ "url" => "https://v5.airtableusercontent.com/file", "filename" => "idea.txt", "type" => "text/plain" }]
    }
    row = mapped_record.deep_merge(auxiliary_mappings: [attachment_mapping])
    proposal = nil

    2.times do
      tempfile = Tempfile.new(["airtable-attachment", ".txt"])
      tempfile.write("attachment content")
      tempfile.rewind
      downloader = instance_double(Decidim::Airtable::AttachmentDownloader)
      allow(downloader).to receive(:download).and_return(io: tempfile, content_type: "application/octet-stream")

      outcome, result = process_row(row, attachment_downloader: downloader)
      expect(outcome).to eq(:ok), result.inspect
      proposal = result[:proposal]
    end

    expect(proposal.attachments.count).to eq(1)
    attachment = proposal.attachments.first
    expect(attachment.file.filename.to_s).to eq("idea.txt")
    expect(attachment.content_type).to eq("text/plain")
    expect(attachment.file.download).to eq("attachment content")
    expect(attachment.file.blob.metadata["airtable_import"]).to include(
      "configuration_id" => import_configuration.id.to_s,
      "record_id" => "rec001",
      "field_id" => "fldAttachment"
    )
  end

  it "writes the proposal ID back to its mapped Airtable field" do
    writeback_mappings = [
      {
        airtable_field_id: "fldProposalId",
        mapping: "writeback_proposal_id",
        metadata: { "kind" => "writeback", "attribute" => "proposal_id" },
        value: ""
      },
      {
        airtable_field_id: "fldProposalUrl",
        mapping: "writeback_proposal_url",
        metadata: { "kind" => "writeback", "attribute" => "proposal_url" },
        value: ""
      }
    ]
    row = mapped_record.deep_merge(auxiliary_mappings: writeback_mappings)
    airtable_client = instance_double(Decidim::Airtable::Api::Client)
    allow(airtable_client).to receive(:update_record)

    outcome, result = process_row(row, airtable_client:)

    expect(outcome).to eq(:ok)
    expect(airtable_client).to have_received(:update_record).with(
      base_id: "appBase123",
      table_id: "tblIdeas123",
      record_id: "rec001",
      fields: {
        "fldProposalId" => result[:proposal].id,
        "fldProposalUrl" => Decidim::ResourceLocatorPresenter.new(result[:proposal]).url
      }
    )
  end

  it "updates the same proposal on retry after Airtable rejects the write-back" do
    writeback_mapping = {
      airtable_field_id: "fldProposalId",
      mapping: "writeback_proposal_id",
      metadata: { "kind" => "writeback", "attribute" => "proposal_id" },
      value: ""
    }
    row = mapped_record.deep_merge(auxiliary_mappings: [writeback_mapping])
    airtable_client = instance_double(Decidim::Airtable::Api::Client)
    allow(airtable_client).to receive(:update_record).and_raise(Decidim::Airtable::Api::Error, "write-back rejected")

    expect do
      outcome, result = process_row(row, airtable_client:)
      expect(outcome).to eq(:invalid)
      expect(result[:error]).to eq("write-back rejected")
    end.to change(Decidim::Proposals::Proposal, :count).by(1)

    tracking = Decidim::Airtable::ImportRecord.find_by!(import_configuration:, airtable_record_id: "rec001")
    original_proposal = tracking.proposal
    expect(tracking).to be_status_failed
    expect(original_proposal).to be_persisted

    allow(airtable_client).to receive(:update_record)

    expect do
      outcome, result = process_row(row, airtable_client:)
      expect(outcome).to eq(:ok)
      expect(result[:operation]).to eq(:updated)
      expect(result[:proposal]).to eq(original_proposal)
    end.not_to change(Decidim::Proposals::Proposal, :count)

    expect(tracking.reload).to be_status_synced
    expect(tracking.proposal).to eq(original_proposal)
  end

  it "records a failed status for unsupported mappings without creating a proposal" do
    unsupported_record = mapped_record.deep_merge(
      auxiliary_mappings: [
        { mapping: "unsupported_target", value: "ignored", metadata: {} }
      ]
    )

    expect do
      outcome, result = process_row(unsupported_record)
      expect(outcome).to eq(:invalid)
      expect(result[:error]).to match(/Unsupported configured mapping/)
    end.not_to change(Decidim::Proposals::Proposal, :count)

    tracking = Decidim::Airtable::ImportRecord.find_by!(import_configuration:, airtable_record_id: "rec001")
    expect(tracking.status).to eq("failed")
    expect(tracking.last_error).to match(/unsupported_target/)
  end
end
