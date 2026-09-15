# frozen_string_literal: true

require "spec_helper"

module Decidim
  describe Decidim::Devise::OmniauthRegistrationsController do
    routes { Decidim::Core::Engine.routes }

    let(:organization) { create(:organization) }
    let(:nyc_strategy) { double("strategy", options: { idp_sso_target_callback_origin: "idp.nyc.gov" }) }

    before do
      request.env["decidim.current_organization"] = organization
      request.env["devise.mapping"] = ::Devise.mappings[:user]
    end

    describe "#saml_callback?" do
      context "when SAML callback origin matches request origin" do
        before do
          request.env["omniauth.strategy"] = nyc_strategy
          request.env["HTTP_ORIGIN"] = "https://idp.nyc.gov"
          allow(request).to receive(:path).and_return("/users/auth/nyc/callback")
        end

        it "returns true" do
          expect(controller.send(:saml_callback?)).to be(true)
        end
      end

      context "when request origin does not match the strategy origin" do
        before do
          request.env["omniauth.strategy"] = nyc_strategy
          request.env["HTTP_ORIGIN"] = "https://evil.example.com"
          allow(request).to receive(:path).and_return("/users/auth/nyc/callback")
        end

        it "returns false" do
          expect(controller.send(:saml_callback?)).to be(false)
        end
      end

      context "when path does not end with /callback" do
        before do
          request.env["omniauth.strategy"] = nyc_strategy
          request.env["HTTP_ORIGIN"] = "https://idp.nyc.gov"
          allow(request).to receive(:path).and_return("/users/auth/nyc/setup")
        end

        it "returns false" do
          expect(controller.send(:saml_callback?)).to be(false)
        end
      end

      context "when the strategy is not SAML" do
        let(:fb_strategy) { double("strategy", options: {}) }

        before do
          request.env["omniauth.strategy"] = fb_strategy
          request.env["HTTP_ORIGIN"] = "https://example.com"
          allow(request).to receive(:path).and_return("/users/auth/facebook/callback")
        end

        it "returns false" do
          expect(controller.send(:saml_callback?)).to be(false)
        end
      end
    end
  end
end
