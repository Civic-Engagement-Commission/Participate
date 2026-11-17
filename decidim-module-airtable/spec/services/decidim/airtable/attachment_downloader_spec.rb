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

    context "with a configured proxy" do
      after { Decidim::Airtable.proxy_url = nil }

      it "opens the connection through the proxy" do
        Decidim::Airtable.proxy_url = "http://user:p%40ss@proxy.example.org:8080"
        response = Net::HTTPNotFound.new("1.1", "404", "Not Found")
        http = instance_double(Net::HTTP, "use_ssl=": true, "open_timeout=": 5, "read_timeout=": 30)

        allow(Net::HTTP).to receive(:new)
          .with("v5.airtableusercontent.com", 443, "proxy.example.org", 8080, "user", "p@ss")
          .and_return(http)
        allow(http).to receive(:start).and_yield(http)
        allow(http).to receive(:request).and_yield(response).and_return(response)

        expect { described_class.new.download("https://v5.airtableusercontent.com/file.pdf") }
          .to raise_error(Decidim::Airtable::AttachmentDownloader::Error, /HTTP 404/)
        expect(Net::HTTP).to have_received(:new)
          .with("v5.airtableusercontent.com", 443, "proxy.example.org", 8080, "user", "p@ss")
      end

      it "turns a refused proxy tunnel into a download error" do
        Decidim::Airtable.proxy_url = "http://proxy.example.org:8080"
        proxy_response = Net::HTTPForbidden.new("1.1", "403", "Forbidden")
        http = instance_double(Net::HTTP, "use_ssl=": true, "open_timeout=": 5, "read_timeout=": 30)

        allow(Net::HTTP).to receive(:new).and_return(http)
        allow(http).to receive(:start).and_raise(Net::HTTPClientException.new('403 "Forbidden"', proxy_response))

        expect { described_class.new.download("https://v5.airtableusercontent.com/file.pdf") }
          .to raise_error(Decidim::Airtable::AttachmentDownloader::Error, /download failed: 403 "Forbidden"/)
      end
    end
  end
end
