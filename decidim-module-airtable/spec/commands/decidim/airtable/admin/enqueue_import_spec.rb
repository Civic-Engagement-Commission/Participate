# frozen_string_literal: true

require_relative "../../../../rails_helper"

describe Decidim::Airtable::Admin::EnqueueImport do
  let(:organization) { create(:organization) }
  let(:current_user) { create(:user, :confirmed, :admin, organization:) }
  let(:import_configuration) do
    Decidim::Airtable::ImportConfiguration.create!(
      organization:,
      airtable_base_id: "appBase123",
      airtable_table_id: "tblIdeas123",
      settings: {},
      active:
    )
  end
  let(:active) { true }

  it "enqueues the import job and broadcasts ok when configuration is active" do
    job = instance_double(Decidim::Airtable::RunImportJob, job_id: "job-123")
    expect(Decidim::Airtable::RunImportJob).to receive(:perform_later) do |configuration_id, user_id, run_id|
      expect(configuration_id).to eq(import_configuration.id)
      expect(user_id).to eq(current_user.id)
      expect(Decidim::Airtable::ImportRun.find(run_id)).to be_status_pending
      job
    end

    state = nil
    result = nil
    described_class.call(import_configuration, current_user) do
      on(:ok) do |import_run|
        state = :ok
        result = import_run
      end
      on(:invalid) { state = :invalid }
    end

    expect(state).to eq(:ok)
    expect(result.job_id).to eq("job-123")
    expect(result.requested_by).to eq(current_user)
  end

  context "when another run is still active" do
    before do
      import_configuration.import_runs.create!(requested_by: current_user, status: :running)
    end

    it "does not enqueue a second run" do
      expect(Decidim::Airtable::RunImportJob).not_to receive(:perform_later)

      state = nil
      described_class.call(import_configuration, current_user) do
        on(:ok) { state = :ok }
        on(:invalid) { state = :invalid }
      end

      expect(state).to eq(:invalid)
      expect(import_configuration.import_runs.count).to eq(1)
    end
  end

  context "when configuration is inactive" do
    let(:active) { false }

    it "broadcasts invalid and does not enqueue a job" do
      expect(Decidim::Airtable::RunImportJob).not_to receive(:perform_later)

      state = nil
      described_class.call(import_configuration, current_user) do
        on(:ok) { state = :ok }
        on(:invalid) { state = :invalid }
      end

      expect(state).to eq(:invalid)
    end
  end
end
