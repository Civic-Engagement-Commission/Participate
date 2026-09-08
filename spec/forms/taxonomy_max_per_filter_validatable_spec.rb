# frozen_string_literal: true

require "spec_helper"
require "decidim/proposals/test/factories"

module Decidim
  module Proposals
    describe ProposalForm do
      subject(:form) { described_class.from_params(params).with_context(context) }

      let(:organization) { create(:organization) }
      let(:participatory_space) { create(:participatory_process, organization:) }
      let(:root_taxonomy) { create(:taxonomy, organization:) }
      let(:taxonomy_item) { create(:taxonomy, parent: root_taxonomy, organization:) }
      let(:other_taxonomy_item) { create(:taxonomy, parent: root_taxonomy, organization:) }
      let(:taxonomy_filter) { create(:taxonomy_filter, root_taxonomy:) }
      let!(:filter_item) { create(:taxonomy_filter_item, taxonomy_filter:, taxonomy_item:) }
      let!(:other_filter_item) { create(:taxonomy_filter_item, taxonomy_filter:, taxonomy_item: other_taxonomy_item) }
      let(:max_taxonomies_per_filter) { 1 }
      let(:component) do
        create(:proposal_component, participatory_space:,
                                    settings: { taxonomy_filters: [taxonomy_filter.id], max_taxonomies_per_filter: })
      end
      let(:author) { create(:user, organization:) }
      let(:taxonomies) { [taxonomy_item.id] }

      let(:params) do
        {
          title: "More sidewalks and less roads!",
          body: "Everything would be better",
          taxonomies:,
          author:
        }
      end

      let(:context) do
        {
          current_component: component,
          current_organization: organization,
          current_participatory_space: participatory_space
        }
      end

      context "when selected taxonomies are within the max per filter" do
        it { is_expected.to be_valid }
      end

      context "when selected taxonomies exceed the max per filter" do
        let(:taxonomies) { [taxonomy_item.id, other_taxonomy_item.id] }

        it "adds a :too_many error on :taxonomies" do
          expect(form).to be_invalid
          expect(form.errors[:taxonomies]).to include("You can choose a maximum of #{max_taxonomies_per_filter} taxonomies per filter.")
        end
      end

      context "when max_taxonomies_per_filter allows more than one taxonomy" do
        let(:max_taxonomies_per_filter) { 2 }
        let(:taxonomies) { [taxonomy_item.id, other_taxonomy_item.id] }

        it { is_expected.to be_valid }
      end
    end
  end
end
