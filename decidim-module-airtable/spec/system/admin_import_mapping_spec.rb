# frozen_string_literal: true

require "rails_helper"

describe "Admin imports mapping" do
  let(:organization) { create(:organization) }
  let(:admin) { create(:user, :confirmed, :admin, organization:) }
  let!(:import_configuration) do
    Decidim::Airtable::ImportConfiguration.create!(
      organization:,
      airtable_base_id: "appBase123",
      airtable_table_id: "tblIdeas123",
      airtable_view_id: "viwOpen",
      settings: {},
      active: true
    )
  end

  before do
    switch_to_host(organization.host)
    login_as admin, scope: :user

    tables_api = instance_double(Decidim::Airtable::Api::Tables)
    allow(Decidim::Airtable::Api::Tables).to receive(:new).and_return(tables_api)
    allow(tables_api).to receive(:for_base).and_return(
      [
        {
          id: "tblIdeas123",
          name: "Ideas",
          fields: [
            { id: "fldA", name: "Author", type: "singleLineText" },
            { id: "fldB", name: "Coauthor", type: "singleLineText" }
          ],
          views: [
            {
              id: "viwOpen",
              name: "Open",
              visible_field_ids: %w(fldA fldB)
            }
          ]
        }
      ]
    )
  end

  it "shows validation errors when writeback target is mapped multiple times" do
    visit "/admin/airtable/imports/#{import_configuration.id}/configure"

    select "Write Decidim proposal ID", from: "import_mapping_form_field_mappings_fldA"
    select "Write Decidim proposal ID", from: "import_mapping_form_field_mappings_fldB"

    click_button "Save mapping"

    expect(page).to have_content("Write Decidim proposal ID can only be mapped once")
  end
end
