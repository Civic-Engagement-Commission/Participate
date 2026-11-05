# frozen_string_literal: true

require_relative "../../../../rails_helper"

describe Decidim::Airtable::Admin::CancelImportRun do
  let(:organization) { create(:organization) }
  let(:current_user) { create(:user, :confirmed, :admin, organization:) }
  let(:import_configuration) do
    Decidim::Airtable::ImportConfiguration.create!(
      organization:,
      airtable_base_id: "appBase123",
      airtable_table_id: "tblIdeas123",
      settings: {},
      active: true
    )
  end

  it "cancels a queued run immediately" do
    import_run = import_configuration.import_runs.create!(requested_by: current_user, status: :pending)
    outcome = nil

    described_class.call(import_run:, organization:) do
      on(:ok) { outcome = :ok }
      on(:invalid) { outcome = :invalid }
    end

    expect(outcome).to eq(:ok)
    expect(import_run.reload).to be_status_cancelled
  end

  it "requests a running job to stop after the current row" do
    import_run = import_configuration.import_runs.create!(requested_by: current_user, status: :running)
    outcome = nil

    described_class.call(import_run:, organization:) do
      on(:ok) { outcome = :ok }
      on(:invalid) { outcome = :invalid }
    end

    expect(outcome).to eq(:ok)
    expect(import_run.reload).to be_status_cancelling
    expect(import_run.completed_at).to be_nil
  end

  it "does not allow cancellation from another organization" do
    import_run = import_configuration.import_runs.create!(requested_by: current_user, status: :running)
    outcome = nil

    described_class.call(import_run:, organization: create(:organization)) do
      on(:ok) { outcome = :ok }
      on(:invalid) { outcome = :invalid }
    end

    expect(outcome).to eq(:invalid)
    expect(import_run.reload).to be_status_running
  end
end
