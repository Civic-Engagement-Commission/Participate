# frozen_string_literal: true

require "spec_helper"

describe "Admin sign-in fallback route" do
  let(:organization) { create(:organization, users_registration_mode:) }

  before do
    switch_to_host(organization.host)
  end

  context "when the organization has users_registration_mode = :disabled (sign_in_enabled? = false)" do
    let(:users_registration_mode) { :disabled }

    it "/users/sign_in does NOT render the password form (upstream behaviour)" do
      visit decidim.new_user_session_path
      expect(page).to have_content("Log in")
      expect(page).to have_no_field("user[email]")
      expect(page).to have_no_field("user[password]")
      expect(page).to have_no_button("Log in")
    end

    it "/admin_sign_in DOES render the password form (NYC override)" do
      visit "/admin_sign_in"
      expect(page).to have_content("Log in")
      expect(page).to have_field("user[email]")
      expect(page).to have_field("user[password]")
      expect(page).to have_button("Log in")
    end
  end

  context "when the organization has users_registration_mode = :enabled (sign_in_enabled? = true)" do
    let(:users_registration_mode) { :enabled }

    it "/users/sign_in renders the password form (upstream behaviour preserved)" do
      visit decidim.new_user_session_path
      expect(page).to have_field("user[email]")
      expect(page).to have_field("user[password]")
      expect(page).to have_button("Log in")
    end
  end
end
