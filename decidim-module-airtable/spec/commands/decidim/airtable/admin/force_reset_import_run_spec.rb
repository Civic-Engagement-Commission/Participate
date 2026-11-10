# frozen_string_literal: true

require_relative "../../../../rails_helper"

describe Decidim::Airtable::Admin::ForceResetImportRun do
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

  it "force-resets an active run" do
    import_run = import_configuration.import_runs.create!(requested_by: current_user, status: :cancelling)
    outcome = nil

    described_class.call(import_run:, organization:) do
      on(:ok) { outcome = :ok }
      on(:invalid) { outcome = :invalid }
    end

    expect(outcome).to eq(:ok)
    expect(import_run.reload).to be_status_cancelled
    expect(import_run.last_error).to include("worker is not terminated")
  end

  it "does not reset a terminal run" do
    import_run = import_configuration.import_runs.create!(requested_by: current_user, status: :completed)
    outcome = nil

    described_class.call(import_run:, organization:) do
      on(:ok) { outcome = :ok }
      on(:invalid) { outcome = :invalid }
    end

    expect(outcome).to eq(:invalid)
    expect(import_run.reload).to be_status_completed
  end
end
