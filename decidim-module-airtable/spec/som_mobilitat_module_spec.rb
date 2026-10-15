# frozen_string_literal: true

require_relative "rails_helper"

describe "AirtableModule" do
  it "defines the Airtable module" do
    expect(Decidim::Airtable).to be_a(Module)
  end

  it "defines the Airtable::Engine class as a subclass of Rails::Engine" do
    expect(Decidim::Airtable::Engine < Rails::Engine).to be true
  end
end
