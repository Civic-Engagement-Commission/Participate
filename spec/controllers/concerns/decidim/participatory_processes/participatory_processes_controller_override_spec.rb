# frozen_string_literal: true

require "spec_helper"

module Decidim
  module ParticipatoryProcesses
    describe ParticipatoryProcessesController do
      routes { Decidim::ParticipatoryProcesses::Engine.routes }

      let(:organization) { create(:organization) }

      describe "default_date_filter" do
        let!(:active) { create(:participatory_process, :published, :active, organization:) }
        let!(:upcoming) { create(:participatory_process, :published, :upcoming, organization:) }
        let!(:past) { create(:participatory_process, :published, :past, organization:) }

        before do
          request.env["decidim.current_organization"] = organization
        end

        it "defaults to all even if there are active published processes" do
          expect(controller.helpers.default_date_filter).to eq("all")
        end

        it "defaults to all if there are upcoming (but no active) published processes" do
          active.update(published_at: nil)
          expect(controller.helpers.default_date_filter).to eq("all")
        end

        it "defaults to all if there are past (but no active nor upcoming) published processes" do
          active.update(published_at: nil)
          upcoming.update(published_at: nil)
          expect(controller.helpers.default_date_filter).to eq("all")
        end

        it "lists every published process regardless of its dates" do
          expect(controller.helpers.participatory_processes).to contain_exactly(active, upcoming, past)
        end

        it "keeps an explicit date filter from params" do
          get :index, params: { filter: { with_date: "active" } }

          expect(controller.helpers.participatory_processes).to contain_exactly(active)
        end
      end
    end
  end
end
