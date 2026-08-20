# frozen_string_literal: true

require "spec_helper"

describe "Google Translate widget" do
  context "with the default Decidim organization" do
    let(:organization) { create(:organization) }

    before do
      switch_to_host(organization.host)
      visit decidim.root_path
    end

    it "loads the Google Translate JS in <head> (via _head_extra override)" do
      expect(page.html).to include("https://translate.google.com/translate_a/element.js")
      expect(page.html).to include("googleTranslateElementInit")
    end

    it "renders the language chooser toggle button in the header (deface insert_before nav)" do
      expect(page).to have_css("#main-language-chooser-toggler")
      expect(page).to have_css("#main-language-chooser-toggler img[alt='Select language']")
    end

    it "renders the language chooser bar with google_translate_element container (deface insert_after main-bar)" do
      expect(page).to have_css("#language-chooser-bar", visible: :all)
      expect(page).to have_css("#google_translate_element", visible: :all)
    end
  end

  context "when inspecting CSP wiring in nyc_overrides initializer" do
    let(:initializer) { Rails.root.join("config/initializers/nyc_overrides.rb").read }

    it "allows scripts/img/connect/style from gstatic.com, google.com, googleapis.com" do
      %w(script-src img-src connect-src style-src).each do |directive|
        expect(initializer).to include(%("#{directive}" =>)), "missing #{directive} directive"
      end
      %w(*.gstatic.com *.google.com *.googleapis.com).each do |host|
        expect(initializer).to include(host), "missing CSP host #{host}"
      end
    end
  end
end
