# frozen_string_literal: true

require_relative "../../../../rails_helper"

describe Decidim::Airtable::Api::Records do
  let(:client) { instance_double(Decidim::Airtable::Api::Client) }
  let(:service) { described_class.new(client:) }

  it "fetches every page for the selected view and preserves Airtable field IDs" do
    allow(client).to receive(:list_records).with(
      base_id: "appBase123",
      table_id: "tblIdeas123",
      view_id: "viwOpen",
      offset: nil
    ).and_return(
      "records" => [{ "id" => "rec001", "fields" => { "fldTitle" => "First" }, "createdTime" => "2026-11-05T12:00:00.000Z" }],
      "offset" => "page-2"
    )
    allow(client).to receive(:list_records).with(
      base_id: "appBase123",
      table_id: "tblIdeas123",
      view_id: "viwOpen",
      offset: "page-2"
    ).and_return("records" => [{ "id" => "rec002", "fields" => { "fldTitle" => "Second" } }])

    result = service.all(base_id: "appBase123", table_id: "tblIdeas123", view_id: "viwOpen")

    expect(client).to have_received(:list_records).with(base_id: "appBase123", table_id: "tblIdeas123", view_id: "viwOpen", offset: nil)
    expect(client).to have_received(:list_records).with(base_id: "appBase123", table_id: "tblIdeas123", view_id: "viwOpen", offset: "page-2")
    expect(result).to eq(
      [
        { id: "rec001", fields: { "fldTitle" => "First" }, created_at: "2026-11-05T12:00:00.000Z" },
        { id: "rec002", fields: { "fldTitle" => "Second" }, created_at: nil }
      ]
    )
  end

  it "raises an Airtable API error for malformed records" do
    allow(client).to receive(:list_records).and_return("records" => [{ "fields" => {} }])

    expect do
      service.all(base_id: "appBase123", table_id: "tblIdeas123")
    end.to raise_error(Decidim::Airtable::Api::Error, /Invalid Airtable records response/)
  end
end
