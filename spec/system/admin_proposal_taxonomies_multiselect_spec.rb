# frozen_string_literal: true

require "spec_helper"
require "decidim/proposals/test/factories"

describe "Admin proposal taxonomies multiselect" do
  include_context "when managing a component as an admin"
  let(:manifest_name) { "proposals" }

  let(:root_taxonomy) { create(:taxonomy, organization:) }
  let(:taxonomy_item) { create(:taxonomy, parent: root_taxonomy, organization:) }
  let(:other_taxonomy_item) { create(:taxonomy, parent: root_taxonomy, organization:) }
  let(:taxonomy_filter) { create(:taxonomy_filter, root_taxonomy:) }
  let!(:filter_item) { create(:taxonomy_filter_item, taxonomy_filter:, taxonomy_item:) }
  let!(:other_filter_item) { create(:taxonomy_filter_item, taxonomy_filter:, taxonomy_item: other_taxonomy_item) }

  let(:second_root_taxonomy) { create(:taxonomy, organization:) }
  let(:second_taxonomy_item) { create(:taxonomy, parent: second_root_taxonomy, organization:) }
  let(:second_other_taxonomy_item) { create(:taxonomy, parent: second_root_taxonomy, organization:) }
  let(:second_third_taxonomy_item) { create(:taxonomy, parent: second_root_taxonomy, organization:) }
  let(:second_taxonomy_filter) { create(:taxonomy_filter, root_taxonomy: second_root_taxonomy) }
  let!(:second_filter_item) { create(:taxonomy_filter_item, taxonomy_filter: second_taxonomy_filter, taxonomy_item: second_taxonomy_item) }
  let!(:second_other_filter_item) { create(:taxonomy_filter_item, taxonomy_filter: second_taxonomy_filter, taxonomy_item: second_other_taxonomy_item) }
  let!(:second_third_filter_item) { create(:taxonomy_filter_item, taxonomy_filter: second_taxonomy_filter, taxonomy_item: second_third_taxonomy_item) }

  let(:component) do
    filter_item
    other_filter_item
    second_filter_item
    second_other_filter_item
    second_third_filter_item

    create(:proposal_component,
           :with_creation_enabled,
           manifest:,
           participatory_space:,
           settings: { taxonomy_filters: [taxonomy_filter.id, second_taxonomy_filter.id],
                       max_taxonomies_per_filter: { taxonomy_filter.id.to_s => 1, second_taxonomy_filter.id.to_s => 2 }.to_json,
                       taxonomies_per_filter_element: { taxonomy_filter.id.to_s => "checkbox", second_taxonomy_filter.id.to_s => "checkbox" }.to_json })
  end

  before do
    visit_component_admin
    click_on "New proposal"
  end

  it "renders radio buttons and checkboxes on the admin form and creates the proposal with the selected taxonomies" do
    radio_fieldset = find("fieldset", text: decidim_sanitize_translated(taxonomy_filter.name))
    expect(radio_fieldset).to have_field(type: "radio")
    expect(radio_fieldset).to have_no_field(type: "checkbox")

    checkbox_fieldset = find("fieldset[data-controller='taxonomy-checkbox-limit']", text: decidim_sanitize_translated(second_taxonomy_filter.name))
    expect(checkbox_fieldset).to have_field(type: "checkbox", count: 3)

    within radio_fieldset do
      find("label", text: decidim_sanitize_translated(taxonomy_item.name), exact_text: true).click
    end

    within checkbox_fieldset do
      find("label", text: decidim_sanitize_translated(second_taxonomy_item.name), exact_text: true).click
      find("label", text: decidim_sanitize_translated(second_other_taxonomy_item.name), exact_text: true).click
      expect(find("input[type=checkbox][value='#{second_third_taxonomy_item.id}']")).to be_disabled
    end

    fill_in_i18n :proposal_title, "#proposal-title-tabs", en: "More sidewalks and less roads"
    fill_in_i18n_editor :proposal_body, "#proposal-body-tabs", en: "Cities need more people, not more cars"

    click_on "Create"

    expect(page).to have_admin_callout("Proposal successfully created.")

    proposal = Decidim::Proposals::Proposal.last
    expect(proposal.taxonomies).to contain_exactly(taxonomy_item, second_taxonomy_item, second_other_taxonomy_item)
  end
end
