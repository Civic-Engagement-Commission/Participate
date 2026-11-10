# frozen_string_literal: true

require_relative "../../../../rails_helper"

describe Decidim::Airtable::Api::Client do
  describe "#list_records" do
    it "requests a selected view with Airtable field IDs" do
      airrecord_client = instance_double(Airrecord::Client)
      connection = instance_double(Faraday::Connection)
      response = instance_double(Faraday::Response, success?: true, body: "{}")
      client = described_class.new(personal_token: "token")

      allow(Airrecord::Client).to receive(:new).with("token").and_return(airrecord_client)
      allow(airrecord_client).to receive(:connection).and_return(connection)
      allow(airrecord_client).to receive(:escape) { |value| "escaped-#{value}" }
      allow(airrecord_client).to receive(:parse).with("{}").and_return("records" => [])

      expect(connection).to receive(:post) do |path, body, headers|
        expect(path).to eq("/v0/escaped-appBase123/escaped-tblIdeas123/listRecords")
        expect(JSON.parse(body)).to eq("returnFieldsByFieldId" => true, "view" => "viwOpen")
        expect(headers).to include("Content-Type" => "application/json")
        response
      end

      expect(client.list_records(base_id: "appBase123", table_id: "tblIdeas123", view_id: "viwOpen")).to eq("records" => [])
    end
  end

  describe "#update_record" do
    it "patches Airtable fields by field ID" do
      airrecord_client = instance_double(Airrecord::Client)
      connection = instance_double(Faraday::Connection)
      response = instance_double(Faraday::Response, success?: true, body: "{}")
      client = described_class.new(personal_token: "token")

      allow(Airrecord::Client).to receive(:new).with("token").and_return(airrecord_client)
      allow(airrecord_client).to receive(:connection).and_return(connection)
      allow(airrecord_client).to receive(:escape) { |value| "escaped-#{value}" }
      allow(airrecord_client).to receive(:parse).with("{}").and_return("id" => "rec001")

      expect(connection).to receive(:patch) do |path, body, headers|
        expect(path).to eq("/v0/escaped-appBase123/escaped-tblIdeas123/escaped-rec001")
        expect(JSON.parse(body)).to eq("fields" => { "fldProposalId" => "42" })
        expect(headers).to include("Content-Type" => "application/json")
        response
      end

      expect(client.update_record(
               base_id: "appBase123",
               table_id: "tblIdeas123",
               record_id: "rec001",
               fields: { "fldProposalId" => "42" }
             )).to eq("id" => "rec001")
    end
  end
end
