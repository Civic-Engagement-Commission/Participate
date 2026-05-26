# frozen_string_literal: true

require "spec_helper"
require "omniauth/strategies/nyc"

describe OmniAuth::Strategies::NYC do
  subject(:strategy) { described_class.new(app) }

  let(:app) { ->(_env) { [200, {}, ["ok"]] } }

  describe "#info" do
    before do
      allow(strategy).to receive(:find_attribute_by) do |values| # rubocop:disable RSpec/SubjectStub
        attribute_stubs.fetch(values.first, nil)
      end
    end

    context "when the IdP returned both first and last name and email is verified" do
      let(:attribute_stubs) do
        {
          "name" => "John Doe",
          "mail" => "john@nyc.gov",
          "email" => "john@nyc.gov",
          "givenName" => "John",
          "sn" => "Doe",
          "nycExtEmailValidationFlag" => "True"
        }
      end

      it "builds the full name from first_name + last_name" do
        expect(strategy.info["name"]).to eq("John Doe")
      end

      it "builds a downcased nickname as <first_name_first_word><last_name_first_char>" do
        expect(strategy.info["nickname"]).to eq("johnd")
      end

      it "keeps the email when nycExtEmailValidationFlag is not 'False'" do
        expect(strategy.info["email"]).to eq("john@nyc.gov")
      end
    end

    context "when nycExtEmailValidationFlag is 'False' (email is not verified by IdP)" do
      let(:attribute_stubs) do
        {
          "name" => "Jane Doe",
          "mail" => "jane@unverified.com",
          "email" => "jane@unverified.com",
          "givenName" => "Jane",
          "sn" => "Doe",
          "nycExtEmailValidationFlag" => "False"
        }
      end

      it "sets email to nil so Decidim asks the user to provide a verified one" do
        expect(strategy.info["email"]).to be_nil
      end
    end

    context "when first_name is missing" do
      let(:attribute_stubs) do
        {
          "givenName" => nil,
          "sn" => "Doe",
          "nycExtEmailValidationFlag" => "True"
        }
      end

      it "falls back to the sn SAML attribute as nickname" do
        expect(strategy.info["nickname"]).to eq("Doe")
      end
    end
  end

  describe OmniAuth::Strategies::EmailNotValidatedError do
    it "inherits from RuntimeError so omniauth's failure_app catches it" do
      expect(described_class.ancestors).to include(RuntimeError)
    end
  end
end
