# frozen_string_literal: true

require_relative "../../../rails_helper"

describe Decidim::Airtable::ImportRun do
  let(:organization) { create(:organization) }
  let(:import_configuration) do
    Decidim::Airtable::ImportConfiguration.create!(
      organization:,
      airtable_base_id: "appBase123",
      airtable_table_id: "tblIdeas123",
      settings: {},
      active: true
    )
  end

  it "records completion counts and per-row errors" do
    run = import_configuration.import_runs.create!(status: :running)
    errors = [{ airtable_record_id: "rec-failed", error: "Invalid title" }]

    run.complete!(
      fetched_count: 4,
      created_count: 2,
      updated_count: 1,
      failed_count: 1,
      errors:
    )

    expect(run).to be_status_completed_with_errors
    expect(run).to have_attributes(fetched_count: 4, created_count: 2, updated_count: 1, failed_count: 1)
    expect(run.error_details.first).to include("airtable_record_id" => "rec-failed", "error" => "Invalid title")
    expect(run.completed_at).to be_present
  end

  it "marks queued and running runs as active" do
    pending_run = import_configuration.import_runs.create!(status: :pending)
    running_run = import_configuration.import_runs.create!(status: :running)
    cancelling_run = import_configuration.import_runs.create!(status: :cancelling)
    completed_run = import_configuration.import_runs.create!(status: :completed)

    expect(described_class.active).to contain_exactly(pending_run, running_run, cancelling_run)
    expect(completed_run).not_to be_status_pending
    expect(completed_run).not_to be_status_running
  end

  it "immediately cancels a queued run" do
    run = import_configuration.import_runs.create!(status: :pending)

    expect(run.request_cancel!).to be(true)
    expect(run.reload).to be_status_cancelled
    expect(run.completed_at).to be_present
  end

  it "requests cooperative cancellation for a running run" do
    run = import_configuration.import_runs.create!(status: :running)

    expect(run.request_cancel!).to be(true)
    expect(run.reload).to be_status_cancelling
    expect(run.completed_at).to be_nil
  end
end
