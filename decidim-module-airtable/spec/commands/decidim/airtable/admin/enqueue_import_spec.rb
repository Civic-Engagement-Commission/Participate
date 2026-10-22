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
    expect(Decidim::Airtable::RunImportJob).to receive(:perform_later).with(import_configuration.id, current_user.id)

    state = nil
    described_class.call(import_configuration, current_user) do
      on(:ok) { state = :ok }
      on(:invalid) { state = :invalid }
    end

    expect(state).to eq(:ok)
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
