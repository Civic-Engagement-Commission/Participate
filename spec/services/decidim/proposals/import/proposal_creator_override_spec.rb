# frozen_string_literal: true

require "spec_helper"
require "decidim/proposals/test/factories"

describe Decidim::Proposals::Import::ProposalCreator do
  subject { described_class.new(data, context) }

  let(:organization) { create(:organization, available_locales: [:en]) }
  let(:user) { create(:user, organization:) }
  let(:participatory_process) { create(:participatory_process, organization:) }
  let(:component) { create(:proposal_component, participatory_space: participatory_process) }
  let(:scope) { create(:scope, organization:) }
  let(:data) do
    {
      taxonomies: { "ids" => [] },
      scope: scope,
      "title/en": "Imported title",
      "body/en": "Imported body",
      address: "Wall street 1",
      latitude: 40.7,
      longitude: -74.0,
      component: component
    }
  end
  let(:context) do
    {
      current_organization: organization,
      current_user: user,
      current_component: component,
      current_participatory_space: participatory_process
    }
  end

  describe "#produce (NYC override)" do
    it "adds the current organization as coauthor instead of current_user" do
      proposal = subject.produce

      expect(proposal.authors).to contain_exactly(organization)
      expect(proposal.authors).not_to include(user)
    end

    it "preserves upstream attributes (title/body/address/scope)" do
      proposal = subject.produce

      expect(proposal.title["en"]).to eq("Imported title")
      expect(proposal.body["en"]).to eq("Imported body")
      expect(proposal.address).to eq("Wall street 1")
      expect(proposal.latitude).to eq(40.7)
      expect(proposal.longitude).to eq(-74.0)
      expect(proposal.scope).to eq(scope)
    end
  end

  describe "#finish! (NYC override)" do
    it "saves the proposal without raising (notify is bypassed)" do
      subject.produce
      expect { subject.finish! }.not_to raise_error
      expect(subject.send(:resource).new_record?).to be(false)
    end

    it "creates an admin-only ActionLog attributed to current_user" do
      subject.produce
      expect { subject.finish! }.to change(Decidim::ActionLog, :count).by(1)
      expect(Decidim::ActionLog.last.user).to eq(user)
      expect(Decidim::ActionLog.last.visibility).to eq("admin-only")
    end

    it "publishes proposal_published event for the participatory space" do
      subject.produce
      expect(Decidim::EventsManager).to receive(:publish).with(
        hash_including(
          event: "decidim.events.proposals.proposal_published",
          event_class: Decidim::Proposals::PublishProposalEvent
        )
      )
      subject.finish!
    end
  end
end
