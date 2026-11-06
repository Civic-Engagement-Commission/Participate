# frozen_string_literal: true

require_relative "../../../rails_helper"
require "decidim/proposals/test/factories"

describe Decidim::Airtable::RunImport do
  let(:organization) { create(:organization) }
  let(:current_user) { create(:user, :confirmed, :admin, organization:) }
  let(:participatory_process) { create(:participatory_process, organization:) }
  let(:component) { create(:proposal_component, participatory_space: participatory_process) }
  let(:records_api) { instance_double(Decidim::Airtable::Api::Records) }
  let(:import_configuration) do
    Decidim::Airtable::ImportConfiguration.create!(
      organization:,
      airtable_base_id: "appBase123",
      airtable_table_id: "tblIdeas123",
      airtable_view_id: "viwOpen",
      settings: {
        "decidim_component_id" => component.id,
        "proposal_field_mappings" => { "fldTitle" => "title", "fldBody" => "body" }
      },
      active:
    )
  end
  let(:active) { true }

  before do
    allow(Decidim::Airtable::Api::Records).to receive(:new).and_return(records_api)
    allow(records_api).to receive(:all).and_return([
                                                     {
                                                       id: "rec001",
                                                       fields: { "fldTitle" => "Community garden", "fldBody" => "A shared garden." },
                                                       created_at: "2026-11-05T12:00:00.000Z"
                                                     }
                                                   ])
  end

  it "fetches the configured view and broadcasts mapped records" do
    state = nil
    payload = nil

    allow(records_api).to receive(:all).with(base_id: "appBase123", table_id: "tblIdeas123", view_id: "viwOpen").and_return(
      [
        {
          id: "rec001",
          fields: { "fldTitle" => "Community garden", "fldBody" => "A shared garden." },
          created_at: "2026-11-05T12:00:00.000Z"
        }
      ]
    )

    described_class.call(import_configuration:, current_user:) do
      on(:ok) do |result|
        state = :ok
        payload = result
      end
      on(:invalid) { state = :invalid }
    end

    expect(records_api).to have_received(:all).with(base_id: "appBase123", table_id: "tblIdeas123", view_id: "viwOpen")
    expect(state).to eq(:ok)
    expect(payload[:fetched_count]).to eq(1)
    expect(payload).to include(fetched_count: 1, mapped_count: 1, created_count: 1, updated_count: 0, failed_count: 0)
    expect(Decidim::Proposals::Proposal.last.title["en"]).to eq("Community garden")
  end

  it "updates the existing proposal title when the same Airtable row changes" do
    allow(records_api).to receive(:all).and_return(
      [{ id: "rec001", fields: { "fldTitle" => "Original title", "fldBody" => "A shared garden." } }],
      [{ id: "rec001", fields: { "fldTitle" => "Corrected title", "fldBody" => "A shared garden." } }]
    )

    2.times do
      described_class.call(import_configuration:, current_user:) do
        on(:invalid) { |result| raise result[:error].to_s }
      end
    end

    expect(Decidim::Proposals::Proposal.count).to eq(1)
    expect(Decidim::Proposals::Proposal.last.title["en"]).to eq("Corrected title")
    expect(Decidim::Airtable::ImportRecord.where(import_configuration:, airtable_record_id: "rec001").count).to eq(1)
  end

  it "includes the mapped proposal title and reference in row error details" do
    allow(records_api).to receive(:all).and_return(
      [
        {
          id: "rec-invalid",
          fields: { "fldTitle" => "A row needing attention", "fldBody" => "" },
          created_at: "2026-11-05T12:00:00.000Z"
        }
      ]
    )
    import_configuration.update!(settings: import_configuration.settings.merge("proposal_field_mappings" => {
                                                                                 "fldTitle" => "title",
                                                                                 "fldBody" => "body",
                                                                                 "fldReference" => "reference"
                                                                               }))

    result = nil
    described_class.call(import_configuration:, current_user:) do
      on(:ok) { |payload| result = payload }
      on(:invalid) { |payload| result = payload }
    end

    expect(result[:failed_count]).to eq(1)
    expect(result[:errors].first).to include(
      airtable_record_id: "rec-invalid",
      proposal_title: "A row needing attention"
    )
  end

  it "fails only the row with an unparseable created_at text value" do
    import_configuration.update!(settings: import_configuration.settings.merge(
      "proposal_field_mappings" => {
        "fldTitle" => "title",
        "fldBody" => "body",
        "fldCreatedAt" => "created_at"
      }
    ))
    allow(records_api).to receive(:all).and_return(
      [
        { id: "rec-invalid-date", fields: { "fldTitle" => "Invalid date row", "fldBody" => "Body", "fldCreatedAt" => "not a date" } },
        { id: "rec-valid-date", fields: { "fldTitle" => "Valid date row", "fldBody" => "Body", "fldCreatedAt" => "2026-10-30 09:00" } }
      ]
    )

    result = nil
    described_class.call(import_configuration:, current_user:) do
      on(:ok) { |payload| result = payload }
      on(:invalid) { |payload| result = payload }
    end

    expect(result).to include(created_count: 1, failed_count: 1, fetched_count: 2)
    expect(result[:errors].first).to include(
      airtable_record_id: "rec-invalid-date",
      proposal_title: "Invalid date row",
      error: include("fldCreatedAt", "created_at")
    )
    expect(Decidim::Proposals::Proposal.count).to eq(1)
    expect(Decidim::Proposals::Proposal.last.title["en"]).to eq("Valid date row")
  end

  it "stops before processing the next row after cancellation is requested" do
    import_run = import_configuration.import_runs.create!(requested_by: current_user, status: :running)
    allow(records_api).to receive(:all).and_return(
      [
        { id: "rec001", fields: { "fldTitle" => "First proposal", "fldBody" => "Body one" } },
        { id: "rec002", fields: { "fldTitle" => "Second proposal", "fldBody" => "Body two" } }
      ]
    )
    allow(Decidim::Airtable::ProcessImportRow).to receive(:call).and_wrap_original do |original, **params, &block|
      result = original.call(**params, &block)
      import_run.update!(status: :cancelling)
      result
    end

    payload = nil
    described_class.call(import_configuration:, current_user:, import_run:) do
      on(:ok) { |result| payload = result }
      on(:invalid) { |result| payload = result }
    end

    expect(Decidim::Airtable::ProcessImportRow).to have_received(:call).once
    expect(payload).to include(created_count: 1, cancelled: true, fetched_count: 2)
    expect(import_run.reload).to be_status_cancelling
  end

  context "when configuration is inactive" do
    let(:active) { false }

    it "broadcasts invalid" do
      state = nil

      described_class.call(import_configuration:, current_user:) do
        on(:ok) { state = :ok }
        on(:invalid) { state = :invalid }
      end

      expect(state).to eq(:invalid)
    end
  end

  context "when the target component is missing" do
    let(:import_configuration) do
      Decidim::Airtable::ImportConfiguration.create!(
        organization:,
        airtable_base_id: "appBase123",
        airtable_table_id: "tblIdeas123",
        settings: {},
        active: true
      )
    end

    it "broadcasts invalid without fetching records" do
      expect(records_api).not_to receive(:all)

      state = nil
      described_class.call(import_configuration:, current_user:) do
        on(:ok) { state = :ok }
        on(:invalid) { state = :invalid }
      end

      expect(state).to eq(:invalid)
    end
  end
end
