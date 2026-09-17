# frozen_string_literal: true

require "spec_helper"
require "decidim/proposals/test/factories"

describe "Proposal taxonomies multiselect" do
  include_context "with a component"
  let(:manifest_name) { "proposals" }

  let(:root_taxonomy) { create(:taxonomy, organization:) }
  let(:taxonomy_item) { create(:taxonomy, parent: root_taxonomy, organization:) }
  let(:other_taxonomy_item) { create(:taxonomy, parent: root_taxonomy, organization:) }
  let(:taxonomy_filter) { create(:taxonomy_filter, root_taxonomy:) }
  let!(:filter_item) { create(:taxonomy_filter_item, taxonomy_filter:, taxonomy_item:) }
  let!(:other_filter_item) { create(:taxonomy_filter_item, taxonomy_filter:, taxonomy_item: other_taxonomy_item) }

  let!(:user) { create(:user, :confirmed, organization:) }

  let(:component) do
    create(:proposal_component,
           :with_creation_enabled,
           manifest:,
           participatory_space: participatory_process,
           settings: { taxonomy_filters: [taxonomy_filter.id],
                       max_taxonomies_per_filter: { taxonomy_filter.id.to_s => max_taxonomies_per_filter }.to_json })
  end

  before do
    component
    login_as user, scope: :user
    visit_component
    click_on "New proposal"
  end

  def select_taxonomy(taxonomy)
    find(".ts-control").click
    find(".ts-dropdown .option", text: decidim_sanitize_translated(taxonomy.name)).click
  end

  context "when only one taxonomy is allowed per filter" do
    let(:max_taxonomies_per_filter) { 1 }

    it "renders a single select that does not allow choosing more than one taxonomy" do
      expect(page).to have_no_css(".ts-control")
      expect(page).to have_css("select#taxonomies-#{taxonomy_filter.id}:not([multiple])", visible: :all)

      select decidim_sanitize_translated(taxonomy_item.name), from: "taxonomies-#{taxonomy_filter.id}"

      within ".new_proposal" do
        fill_in :proposal_title, with: "More sidewalks and less roads"
        fill_in :proposal_body, with: "Cities need more people, not more cars"
        expect(page).to have_select("taxonomies-#{taxonomy_filter.id}", selected: decidim_sanitize_translated(taxonomy_item.name), visible: :all)
        find("*[type=submit]").click
      end
      click_on "Publish"

      expect(page).to have_content("successfully")
      expect(page).to have_content(decidim_sanitize_translated(taxonomy_item.name))
    end
  end

  context "when more than one taxonomy is allowed per filter" do
    let(:max_taxonomies_per_filter) { 2 }

    it "allows selecting up to the allowed number of taxonomies" do
      select_taxonomy(taxonomy_item)
      select_taxonomy(other_taxonomy_item)
      expect(page).to have_css(".ts-control .item", count: 2)

      within ".new_proposal" do
        fill_in :proposal_title, with: "More sidewalks and less roads"
        fill_in :proposal_body, with: "Cities need more people, not more cars"
        expect(page).to have_select(
          "taxonomies-#{taxonomy_filter.id}",
          selected: [decidim_sanitize_translated(taxonomy_item.name), decidim_sanitize_translated(other_taxonomy_item.name)],
          visible: :all
        )
        find("*[type=submit]").click
      end
      click_on "Publish"

      expect(page).to have_css("[data-tags] .tag", count: 2)
      expect(page).to have_content("successfully")
      expect(page).to have_content(decidim_sanitize_translated(taxonomy_item.name))
      expect(page).to have_content(decidim_sanitize_translated(other_taxonomy_item.name))
    end
  end
end
