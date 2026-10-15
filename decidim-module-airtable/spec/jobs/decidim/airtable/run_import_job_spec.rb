# frozen_string_literal: true

require_relative "../../../rails_helper"

describe Decidim::Airtable::RunImportJob do
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

  it "calls the run import command with the configuration" do
    expect(Decidim::Airtable::RunImport).to receive(:call).with(import_configuration:)

    described_class.perform_now(import_configuration.id)
  end

  it "returns silently when configuration is missing" do
    expect(Decidim::Airtable::RunImport).not_to receive(:call)

    expect { described_class.perform_now(-1) }.not_to raise_error
  end
end
