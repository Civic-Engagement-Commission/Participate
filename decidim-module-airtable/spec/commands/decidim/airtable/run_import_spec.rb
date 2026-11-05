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
