# frozen_string_literal: true

require_relative "../../../../rails_helper"

describe Decidim::Airtable::Admin::ImportConfigurationForm do
  subject(:form) { described_class.from_params(params).with_context(context) }

  let(:organization) { create(:organization) }
  let(:other_organization) { create(:organization) }

  let(:params) do
    {
      airtable_base_id: "appBase123",
      airtable_table_id: "tblIdeas123",
      airtable_view_id: "viwDefault",
      active: true
    }
  end

  let(:context) do
    {
      current_organization: organization
    }
  end

  describe "validations" do
    context "when organization, base and table are present" do
      it "is valid" do
        expect(form).to be_valid
      end
    end

    context "when same organization/base/table already exists" do
      before do
        Decidim::Airtable::ImportConfiguration.create!(
          organization:,
          airtable_base_id: "appBase123",
          airtable_table_id: "tblIdeas123",
          airtable_view_id: "viwExisting",
          active: true,
          settings: {}
        )
      end

      it "is invalid" do
        expect(form).to be_invalid
        expect(form.errors.details[:airtable_table_id]).to include(error: :already_configured_for_organization_and_base)
      end
    end

    context "when same table exists in another organization" do
      before do
        Decidim::Airtable::ImportConfiguration.create!(
          organization: other_organization,
          airtable_base_id: "appBase123",
          airtable_table_id: "tblIdeas123",
          airtable_view_id: "viwExisting",
          active: true,
          settings: {}
        )
      end

      it "is valid" do
        expect(form).to be_valid
      end
    end

    context "when editing existing configuration" do
      let!(:import_configuration) do
        Decidim::Airtable::ImportConfiguration.create!(
          organization:,
          airtable_base_id: "appBase123",
          airtable_table_id: "tblIdeas123",
          airtable_view_id: "viwExisting",
          active: true,
          settings: {}
        )
      end

      let(:params) do
        {
          id: import_configuration.id,
          airtable_base_id: "appBase123",
          airtable_table_id: "tblIdeas123",
          airtable_view_id: "viwUpdated"
        }
      end

      it "allows keeping the same table for the same record" do
        expect(form).to be_valid
      end
    end
  end
end
