# frozen_string_literal: true

require_relative "../../../rails_helper"

describe Decidim::Airtable::AttachmentDownloader do
  describe "#download" do
    it "rejects non-HTTPS and non-Airtable attachment URLs" do
      downloader = described_class.new

      expect { downloader.download("http://airtableusercontent.com/file.pdf") }
        .to raise_error(Decidim::Airtable::AttachmentDownloader::Error, /URL is not allowed/)
      expect { downloader.download("https://example.org/file.pdf") }
        .to raise_error(Decidim::Airtable::AttachmentDownloader::Error, /URL is not allowed/)
    end
  end
end
