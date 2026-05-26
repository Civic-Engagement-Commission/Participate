# frozen_string_literal: true

require "spec_helper"

describe "NYC.ID login" do
  let(:organization) { create(:organization) }
  let(:omniauth_providers) do
    {
      nyc: {
        enabled: true,
        provider_name: "NYC ID",
        icon_path: "media/images/nyc-id.svg",
        sign_in_button_text: "Sign in with NYC.ID",
        sign_up_button_url: "https://accounts-nonprd.nyc.gov/account/user/register.htm",
        sign_up_button_sp_name: "Decidim NYC",
        sign_up_button_target: "https://example.org/users/auth/nyc/callback",
        sign_up_button_text: "Create account with NYC.ID"
      }
    }
  end
  let(:omniauth_hash) do
    OmniAuth::AuthHash.new(
      provider: "nyc",
      uid: "nyc-uid-1",
      info: {
        email: "user@nyc.gov",
        nickname: "johnd",
        name: "John Doe"
      }
    )
  end

  before do
    allow(Decidim).to receive(:omniauth_providers).and_return(omniauth_providers)
    switch_to_host(organization.host)

    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:nyc] = omniauth_hash
    OmniAuth.config.add_camelization "nyc", "NYC"
    OmniAuth.config.request_validation_phase = ->(env) {} if OmniAuth.config.respond_to?(:request_validation_phase)
  end

  after do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:nyc] = nil
    OmniAuth.config.camelizations.delete("nyc")
  end

  describe "buttons on the sign-in page" do
    before { visit decidim.new_user_session_path }

    it "renders the NYC.ID sign-in button" do
      expect(page).to have_link("Sign in with NYC.ID")
    end

    it "renders the NYC.ID 'Create account' button pointing to the external sign-up URL" do
      link = find_link("Create account with NYC.ID")
      expect(link[:href]).to start_with("https://accounts-nonprd.nyc.gov/account/user/register.htm")
      expect(link[:href]).to include("spName=Decidim+NYC")
    end
  end

  describe "full sign-in flow via NYC.ID" do
    it "creates a new user and logs them in" do
      visit decidim.new_user_session_path
      click_on "Sign in with NYC.ID"

      check :registration_user_tos_agreement
      within "#omniauth-register-form" do
        click_on "Create an account"
      end

      sleep 1

      click_on "Keep unchecked"

      expect(page).to have_content("Successfully")
      expect(Decidim::User.find_by(email: "user@nyc.gov")).to be_present
    end
  end
end
