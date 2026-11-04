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
      let(:taxonomy_filter) { create(:taxonomy_filter, root_taxonomy:, name: { en: "District" }) }
      let!(:filter_item) { create(:taxonomy_filter_item, taxonomy_filter:, taxonomy_item:) }
      let(:other_root_taxonomy) { create(:taxonomy, organization:) }
      let(:other_taxonomy_item) { create(:taxonomy, parent: other_root_taxonomy, organization:) }
      let(:other_taxonomy_filter) { create(:taxonomy_filter, root_taxonomy: other_root_taxonomy, name: { en: "Topic" }) }
      let!(:other_filter_item) { create(:taxonomy_filter_item, taxonomy_filter: other_taxonomy_filter, taxonomy_item: other_taxonomy_item) }
      let(:taxonomy_filter_ids) { [taxonomy_filter.id, other_taxonomy_filter.id] }
      let(:component) do
        create(:proposal_component, participatory_space:,
                                    settings: { taxonomy_filters: taxonomy_filter_ids,
                                                max_taxonomies_per_filter: {}.to_json })
      end
      let(:author) { create(:user, organization:) }
      let(:taxonomies) { [taxonomy_item.id, other_taxonomy_item.id] }
      let(:required) { true }

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

      before do
        allow(Decidim::Nyc::TaxonomyFilterSettings).to receive(:required?).and_return(required)
      end

      context "when every filter has a taxonomy" do
        it { is_expected.to be_valid }
      end

      context "when no taxonomies are selected" do
        let(:taxonomies) { [] }

        it "adds a :blank_for_filter error on each filter error key" do
          expect(form).to be_invalid
          expect(form.errors[:"taxonomies_#{taxonomy_filter.id}"]).to eq(["Please choose at least one option for District."])
          expect(form.errors[:"taxonomies_#{other_taxonomy_filter.id}"]).to eq(["Please choose at least one option for Topic."])
          expect(form.errors[:taxonomies]).to be_empty
        end
      end

      context "when only one filter has a taxonomy" do
        let(:taxonomies) { [taxonomy_item.id] }

        it "adds a :blank_for_filter error only on the empty filter error key" do
          expect(form).to be_invalid
          expect(form.errors[:"taxonomies_#{taxonomy_filter.id}"]).to be_empty
          expect(form.errors[:"taxonomies_#{other_taxonomy_filter.id}"]).to eq(["Please choose at least one option for Topic."])
        end
      end

      context "when taxonomies are not required" do
        let(:required) { false }
        let(:taxonomies) { [] }

        it { is_expected.to be_valid }
      end

      context "when the component has no taxonomy filters" do
        let(:taxonomy_filter_ids) { [] }
        let(:taxonomies) { [] }

        it { is_expected.to be_valid }
      end

      context "when a filter has no items" do
        let!(:other_filter_item) { nil }
        let(:taxonomies) { [taxonomy_item.id] }

        it { is_expected.to be_valid }
      end
    end

    describe Admin::ProposalForm do
      subject(:form) { described_class.from_params(params).with_context(context) }

      let(:organization) { create(:organization) }
      let(:participatory_space) { create(:participatory_process, organization:) }
      let(:root_taxonomy) { create(:taxonomy, organization:) }
      let(:taxonomy_item) { create(:taxonomy, parent: root_taxonomy, organization:) }
      let(:taxonomy_filter) { create(:taxonomy_filter, root_taxonomy:, name: { en: "District" }) }
      let!(:filter_item) { create(:taxonomy_filter_item, taxonomy_filter:, taxonomy_item:) }
      let(:component) do
        create(:proposal_component, participatory_space:,
                                    settings: { taxonomy_filters: [taxonomy_filter.id],
                                                max_taxonomies_per_filter: {}.to_json })
      end
      let(:params) do
        {
          title: { en: "More sidewalks and less roads!" },
          body: { en: "Everything would be better" },
          taxonomies: [],
          created_in_meeting: false
        }
      end
      let(:context) do
        {
          current_component: component,
          current_organization: organization,
          current_participatory_space: participatory_space
        }
      end

      before do
        allow(Decidim::Nyc::TaxonomyFilterSettings).to receive(:required?).and_return(true)
      end

      it "adds a :blank_for_filter error when no taxonomies are selected" do
        expect(form).to be_invalid
        expect(form.errors[:"taxonomies_#{taxonomy_filter.id}"]).to eq(["Please choose at least one option for District."])
      end
    end
  end
end
