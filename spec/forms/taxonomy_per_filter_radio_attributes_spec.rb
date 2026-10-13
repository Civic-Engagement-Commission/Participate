# frozen_string_literal: true

require "spec_helper"

module Decidim
  module Proposals
    describe ProposalForm do
      subject(:form) { described_class.from_params(params) }

      let(:params) do
        {
          title: "More sidewalks and less roads!",
          body: "Everything would be better",
          taxonomies: [3],
          taxonomies_by_filter:
        }
      end

      context "when a radio filter has a selected taxonomy" do
        let(:taxonomies_by_filter) { { "1" => "5", "2" => "7" } }

        it "merges the selected taxonomies into taxonomies" do
          expect(form.taxonomies).to contain_exactly(3, 5, 7)
        end
      end

      context "when a radio filter is left empty" do
        let(:taxonomies_by_filter) { { "1" => "", "2" => "7" } }

        it "ignores the empty value" do
          expect(form.taxonomies).to contain_exactly(3, 7)
        end
      end
    end
  end
end
