# frozen_string_literal: true

require "rails_helper"

describe Decidim::Airtable::Admin::CreateImportConfiguration do
  subject(:run_command) { described_class.call(form) }

  let(:organization) { create(:organization) }
  let(:user) { create(:user, :confirmed, :admin, organization:) }
  let(:params) do
    {
      airtable_base_id: "appBase123",
      airtable_base_name: "Community Ideas",
      airtable_table_id: "tblIdeas123",
      airtable_table_name: "Ideas",
      airtable_view_id: "viwOpen",
      airtable_view_name: "Open ideas",
      active: true
    }
  end
  let(:form) do
    Decidim::Airtable::Admin::ImportConfigurationForm
      .from_params(params)
      .with_context(current_organization: organization)
  end

  before do
    allow(form).to receive(:current_user).and_return(user)
  end

  it "creates the import configuration and broadcasts ok" do
    result = nil

    described_class.call(form) do
      on(:ok) { |import_configuration| result = import_configuration }
      on(:invalid) { raise "expected command to be valid" }
    end

    expect(result).to be_present
    expect(result.organization).to eq(organization)
    expect(result.airtable_base_id).to eq("appBase123")
    expect(result.settings).to include(
      "airtable_base_name" => "Community Ideas",
      "airtable_table_name" => "Ideas",
      "airtable_view_name" => "Open ideas"
    )
  end

  context "when form is invalid" do
    let(:params) do
      {
        airtable_base_id: nil,
        airtable_table_id: nil
      }
    end

    it "broadcasts invalid and does not create records" do
      expect do
        run_command
      end.not_to change(Decidim::Airtable::ImportConfiguration, :count)
    end
  end
end
