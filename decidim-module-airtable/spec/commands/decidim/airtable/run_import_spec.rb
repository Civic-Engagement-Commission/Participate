# frozen_string_literal: true

require_relative "../../../rails_helper"

describe Decidim::Airtable::RunImport do
  let(:organization) { create(:organization) }
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

  it "broadcasts ok for active configurations" do
    state = nil
    payload = nil

    described_class.call(import_configuration:) do
      on(:ok) do |result|
        state = :ok
        payload = result
      end
      on(:invalid) { state = :invalid }
    end

    expect(state).to eq(:ok)
    expect(payload).to include(imported_count: 0, updated_count: 0, skipped_count: 0)
  end

  context "when configuration is inactive" do
    let(:active) { false }

    it "broadcasts invalid" do
      state = nil

      described_class.call(import_configuration:) do
        on(:ok) { state = :ok }
        on(:invalid) { state = :invalid }
      end

      expect(state).to eq(:invalid)
    end
  end
end
