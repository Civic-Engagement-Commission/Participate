# frozen_string_literal: true

require_relative "../../../rails_helper"

describe Decidim::Airtable::ProposalCustomFieldsUpdater do
  let(:organization) { create(:organization) }
  let(:component) { create(:component, participatory_space: create(:participatory_process, organization:), manifest_name: "proposals") }
  let(:current_user) { create(:user, organization:) }
  let(:config) { instance_double(Decidim::DecidimAwesome::Config) }
  let(:proposal) { double("proposal", body: { "en" => "" }) }
  let(:updater) { described_class.new(organization:, component:, current_user:) }
  let(:field_definition) do
    {
      "name" => "project_name",
      "label" => "Project name",
      "type" => "text"
    }.to_json
  end

  before do
    allow(Decidim::DecidimAwesome::Config).to receive(:new).with(organization).and_return(config)
    allow(config).to receive(:context_from_component!).with(component)
    allow(config).to receive(:application_context!).with(current_user:)
    allow(config).to receive(:collect_sub_configs_values).with("proposal_custom_field").and_return([field_definition])
  end

  it "writes mapped public values in the Awesome custom-field XML format" do
    allow(proposal).to receive(:body=)

    updater.apply(
      proposal,
      [
        {
          mapping: "awesome_custom:public:project_name",
          value: "Community garden",
          metadata: { "visibility" => "public", "name" => "project_name" }
        }
      ]
    )

    expect(proposal).to have_received(:body=) do |body|
      expect(body["en"]).to include("<dl", "id=\"project_name\"")
      expect(Nokogiri::XML(body["en"]).at_css("dd#project_name div").text).to eq("Community garden")
    end
  end

  it "preserves the prior custom-field value when updating another field" do
    previous_xml = '<xml><dl class="decidim_awesome-custom_fields"><dt name="project_name">Project name</dt><dd id="project_name" name="text"><div>Existing name</div></dd></dl></xml>'
    allow(proposal).to receive(:body).and_return("en" => previous_xml)
    allow(proposal).to receive(:body=)

    updater.apply(
      proposal,
      [
        {
          mapping: "awesome_custom:public:project_name",
          value: "Updated name",
          metadata: { "visibility" => "public", "name" => "project_name" }
        }
      ]
    )

    expect(proposal).to have_received(:body=) do |body|
      expect(Nokogiri::XML(body["en"]).at_css("dd#project_name div").text).to eq("Updated name")
    end
  end
end
