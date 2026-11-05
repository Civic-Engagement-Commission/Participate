# frozen_string_literal: true

require_relative "../../../rails_helper"
require "decidim/proposals/test/factories"

describe Decidim::Airtable::RunImportJob do
  let(:organization) { create(:organization) }
  let(:current_user) { create(:user, :confirmed, :admin, organization:) }
  let(:component) { create(:proposal_component, participatory_space: create(:participatory_process, organization:)) }
  let(:import_configuration) do
    Decidim::Airtable::ImportConfiguration.create!(
      organization:,
      airtable_base_id: "appBase123",
      airtable_table_id: "tblIdeas123",
      settings: {
        "decidim_component_id" => component.id,
        "proposal_field_mappings" => { "fldTitle" => "title", "fldBody" => "body" }
      },
      active: true
    )
  end
  let!(:import_run) do
    import_configuration.import_runs.create!(requested_by: current_user, status: :pending)
  end

  it "tracks the run lifecycle and saves the command result" do
    records_api = instance_double(Decidim::Airtable::Api::Records, all: [])
    allow(Decidim::Airtable::Api::Records).to receive(:new).and_return(records_api)

    described_class.perform_now(import_configuration.id, current_user.id, import_run.id)

    expect(import_run.reload).to be_status_completed
    expect(import_run.started_at).to be_present
    expect(import_run.completed_at).to be_present
    expect(import_run.fetched_count).to eq(0)
  end

  it "marks the run failed when the requester is no longer available" do
    described_class.perform_now(import_configuration.id, -1, import_run.id)

    expect(import_run.reload).to be_status_failed
    expect(import_run.last_error).to include("Requesting admin")
  end

  it "cancels after the current row and preserves partial results" do
    records_api = instance_double(
      Decidim::Airtable::Api::Records,
      all: [
        { id: "rec001", fields: { "fldTitle" => "First proposal", "fldBody" => "First body" } },
        { id: "rec002", fields: { "fldTitle" => "Second proposal", "fldBody" => "Second body" } }
      ]
    )
    allow(Decidim::Airtable::Api::Records).to receive(:new).and_return(records_api)
    allow(Decidim::Airtable::ProcessImportRow).to receive(:call).and_wrap_original do |original, **params, &block|
      result = original.call(**params, &block)
      import_run.update!(status: :cancelling)
      result
    end

    described_class.perform_now(import_configuration.id, current_user.id, import_run.id)

    expect(Decidim::Airtable::ProcessImportRow).to have_received(:call).once
    expect(import_run.reload).to be_status_cancelled
    expect(import_run.created_count).to eq(1)
    expect(import_run.fetched_count).to eq(2)
  end

  it "returns silently when configuration is missing" do
    expect(Decidim::Airtable::RunImport).not_to receive(:call)

    expect { described_class.perform_now(-1) }.not_to raise_error
  end
end
