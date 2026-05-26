# frozen_string_literal: true

require "spec_helper"

describe ApplicationHelper do
  describe "#omniauth_sign_up_url (NYC.ID sign-up button)" do
    let(:base_url) { "https://idp.nyc.gov/sign-up" }
    let(:target_url) { "https://decidim.nyc.gov/users/auth/nyc/callback" }

    before do
      allow(helper).to receive(:current_locale).and_return("en")
    end

    context "when sign_up_button_url is blank" do
      it "returns nil for nil URL" do
        expect(helper.omniauth_sign_up_url(sign_up_button_url: nil)).to be_nil
      end

      it "returns nil for empty URL" do
        expect(helper.omniauth_sign_up_url(sign_up_button_url: "")).to be_nil
      end
    end

    context "when sign_up_button_url is present" do
      let(:config) do
        {
          sign_up_button_url: base_url,
          sign_up_button_sp_name: "Decidim NYC",
          sign_up_button_target: target_url
        }
      end

      it "preserves the base host and path" do
        url = helper.omniauth_sign_up_url(config)
        expect(URI(url).host).to eq("idp.nyc.gov")
        expect(URI(url).path).to eq("/sign-up")
      end

      it "adds showNameFields=false, spName and Base64-encoded target" do
        url = helper.omniauth_sign_up_url(config)
        params = Rack::Utils.parse_query(URI(url).query)

        expect(params["showNameFields"]).to eq("false")
        expect(params["spName"]).to eq("Decidim NYC")
        expect(params["target"]).to eq(Base64.urlsafe_encode64(target_url))
      end

      it "uses the current locale for lang param" do
        allow(helper).to receive(:current_locale).and_return("es")
        url = helper.omniauth_sign_up_url(config)
        params = Rack::Utils.parse_query(URI(url).query)
        expect(params["lang"]).to eq("es")
      end
    end
  end
end
