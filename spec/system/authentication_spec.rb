# frozen_string_literal: true

require "spec_helper"

describe "Authentication" do
  let(:organization) { create(:organization) }
  let(:last_user) { Decidim::User.last }
  let(:omniauth_secrets) do
    {
      facebook: {
        enabled: true,
        app_id: "fake-facebook-app-id",
        app_secret: "fake-facebook-app-secret",
        icon: "phone"
      },
      google_oauth2: {
        enabled: true,
        client_id: nil,
        client_secret: nil,
        icon: "phone"
      }
    }
  end

  before do
    allow(Decidim).to receive(:omniauth_providers).and_return(omniauth_secrets)
    switch_to_host(organization.host)
    visit decidim.root_path
  end

  around do |example|
    previous_value = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    begin
      example.run
    ensure
      ActionController::Base.allow_forgery_protection = previous_value
    end
  end

  describe "Create an account" do
    around do |example|
      perform_enqueued_jobs { example.run }
    end

    context "when being a robot" do
      it "denies the sign up" do
        click_on "Create an account"

        within ".new_user" do
          page.execute_script("$($('.new_user > div > input')[0]).val('Ima robot :D')")
          fill_in :registration_user_email, with: "user@example.org"
          fill_in :registration_user_name, with: "Responsible Citizen"
          fill_in :registration_user_password, with: "DfyvHn425mYAy2HL"
          check :registration_user_tos_agreement
          check :registration_user_newsletter
          find("*[type=submit]").click
        end

        expect(page).to have_no_content("confirmation link")
      end
    end

    context "when using google" do
      let(:omniauth_hash) do
        OmniAuth::AuthHash.new(
          provider: "google_oauth2",
          uid: "123545",
          info: {
            name: "Google User",
            nickname: "google_user",
            email: "user@from-google.com"
          }
        )
      end

      before do
        OmniAuth.config.test_mode = true
        OmniAuth.config.mock_auth[:google_oauth2] = omniauth_hash

        OmniAuth.config.add_camelization "google_oauth2", "GoogleOauth"
        OmniAuth.config.request_validation_phase = ->(env) {} if OmniAuth.config.respond_to?(:request_validation_phase)
      end

      after do
        OmniAuth.config.test_mode = false
        OmniAuth.config.mock_auth[:google_oauth2] = nil
        OmniAuth.config.camelizations.delete("google_oauth2")
      end

      it "creates a new User" do
        click_on "Create an account"

        click_on "Log in with Google"
        check :registration_user_tos_agreement
        check :registration_user_newsletter
        within "#omniauth-register-form" do
          click_on "Create an account"
        end

        expect_user_logged
      end

      it "sends a welcome notification" do
        click_on "Create an account"

        click_on "Log in with Google"
        check :registration_user_tos_agreement
        check :registration_user_newsletter
        within "#omniauth-register-form" do
          click_on "Create an account"
        end

        within_user_menu do
          click_on "Notifications"
        end

        within "#notifications" do
          expect(page).to have_content("thanks for joining #{translated(organization.name)}")
        end

        expect(last_email_body).to include("thanks for joining #{translated(organization.name)}")
      end
    end

    context "when sign up is disabled" do
      let(:organization) { create(:organization, users_registration_mode: :existing) }

      it "redirects to the sign in when accessing the sign up page" do
        visit decidim.new_user_registration_path
        expect(page).to have_no_content("Create an account")
      end

      it "do not allow the user to sign up" do
        click_on("Log in", match: :first)
        expect(page).to have_no_content("Create an account")
      end
    end
  end

  context "when a user is already registered with a social provider" do
    let(:user) { create(:user, :confirmed, organization:) }
    let(:identity) { create(:identity, user:, provider: "facebook", uid: "12345") }

    let(:omniauth_hash) do
      OmniAuth::AuthHash.new(
        provider: identity.provider,
        uid: identity.uid,
        info: {
          email: user.email,
          name: "Facebook User",
          verified: true
        }
      )
    end

    before do
      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[:facebook] = omniauth_hash
      OmniAuth.config.add_camelization "facebook", "FaceBook"
      OmniAuth.config.request_validation_phase = ->(env) {} if OmniAuth.config.respond_to?(:request_validation_phase)
    end

    after do
      OmniAuth.config.test_mode = false
      OmniAuth.config.mock_auth[:facebook] = nil
      OmniAuth.config.camelizations.delete("facebook")
    end

    describe "Log in" do
      it "authenticates an existing User" do
        click_on("Log in", match: :first)

        find(".login__omniauth-button.login__omniauth-button--facebook").click

        expect(page).to have_content("Successfully")
        expect_current_user_to_be(user)
      end

      context "when sign up is disabled" do
        let(:organization) { create(:organization, users_registration_mode: :existing) }

        it "does not allow the user to sign up" do
          click_on("Log in", match: :first)
          expect(page).to have_no_content("Create an account")
        end
      end

      context "when sign in is disabled" do
        let(:organization) { create(:organization, users_registration_mode: :disabled) }

        it "does not allow the user to sign up" do
          click_on("Log in", match: :first)
          expect(page).to have_no_content("Create an account")
        end

        it "does not allow the user to sign in as a regular user, only through external accounts" do
          click_on("Log in", match: :first)
          expect(page).to have_no_content("Email")
          within("div.login__omniauth") do
            expect(page).to have_link("Facebook")
          end
        end

        it "authenticates an existing User" do
          click_on("Log in", match: :first)

          find(".login__omniauth-button.login__omniauth-button--facebook").click

          expect(page).to have_content("Successfully")
          expect_current_user_to_be(user)
        end

        context "when admin password is expired" do
          let(:user) { create(:user, :confirmed, :admin, password_updated_at: 91.days.ago, organization:) }

          before do
            allow(Decidim.config).to receive(:admin_password_expiration_days).and_return(90)
          end

          it "can log in without being prompted to change the password" do
            click_on("Log in", match: :first)
            click_on "Log in with Facebook"
            expect(page).to have_content("Successfully")
          end
        end
      end
    end
  end
end

def expect_current_user_to_be(user)
  within_user_menu do
    click_on "My public profile"
  end
  expect(page).to have_content(user.name)
end
