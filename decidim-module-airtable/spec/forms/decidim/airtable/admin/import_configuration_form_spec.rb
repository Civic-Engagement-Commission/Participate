# frozen_string_literal: true

require_relative "../../../../rails_helper"

describe Decidim::Airtable::Admin::ImportConfigurationForm do
  subject(:form) { described_class.from_params(params).with_context(context) }

  let(:organization) { create(:organization) }
  let(:other_organization) { create(:organization) }
  let(:participatory_process) { create(:participatory_process, organization:) }
  let(:component) { create(:component, participatory_space: participatory_process, manifest_name: "proposals") }

  let(:params) do
    {
      airtable_base_id: "appBase123",
      airtable_table_id: "tblIdeas123",
      airtable_view_id: "viwDefault",
      decidim_component_id: component.id,
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

    context "when component does not belong to organization" do
      let(:other_process) { create(:participatory_process, organization: other_organization) }
      let(:other_component) { create(:component, participatory_space: other_process, manifest_name: "proposals") }
      let(:params) do
        super().merge(decidim_component_id: other_component.id)
      end

      it "is invalid" do
        expect(form).to be_invalid
        expect(form.errors[:decidim_component_id]).to be_present
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
          airtable_view_id: "viwUpdated",
          decidim_component_id: component.id
        }
      end

      it "allows keeping the same table for the same record" do
        expect(form).to be_valid
      end
    end
  end
end
