# frozen_string_literal: true

require "net/http"
require "tempfile"
require "uri"

module Decidim
  module Airtable
    class AttachmentDownloader
      class Error < StandardError; end

      MAX_FILE_BYTES = 20 * 1024 * 1024
      MAX_REDIRECTS = 3
      ALLOWED_HOSTS = %w(airtableusercontent.com dl.airtable.com).freeze

      def download(url)
        uri = URI.parse(url)
        redirects = 0

        loop do
          validate_uri!(uri)
          tempfile = Tempfile.new(["airtable-import", File.extname(uri.path)])
          tempfile.binmode

          response = request(uri, tempfile)
          if response.is_a?(Net::HTTPSuccess)
            tempfile.rewind
            return { io: tempfile, content_type: response["content-type"] }
          end

          tempfile.close!
          raise Error, "Airtable attachment download failed with HTTP #{response.code}" unless response.is_a?(Net::HTTPRedirection) && response["location"].present?
          raise Error, "Airtable attachment exceeded the redirect limit" if redirects >= MAX_REDIRECTS

          uri = URI.join(uri.to_s, response["location"])
          redirects += 1
        end
      rescue URI::InvalidURIError => e
        raise Error, "Invalid Airtable attachment URL: #{e.message}"
      rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, IOError => e
        raise Error, "Airtable attachment download failed: #{e.message}"
      end

      private

      def validate_uri!(uri)
        allowed_host = ALLOWED_HOSTS.any? { |host| uri.host == host || uri.host&.end_with?(".#{host}") }
        raise Error, "Airtable attachment URL is not allowed" unless uri.is_a?(URI::HTTPS) && allowed_host
      end

      def request(uri, tempfile)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.open_timeout = 5
        http.read_timeout = 30
        request = Net::HTTP::Get.new(uri.request_uri)
        response = nil

        http.start do |connection|
          connection.request(request) do |result|
            response = result
            next unless result.is_a?(Net::HTTPSuccess)

            content_length = result["content-length"].to_i
            raise Error, "Airtable attachment exceeds the #{MAX_FILE_BYTES} byte limit" if content_length > MAX_FILE_BYTES

            bytes_written = 0
            result.read_body do |chunk|
              bytes_written += chunk.bytesize
              raise Error, "Airtable attachment exceeds the #{MAX_FILE_BYTES} byte limit" if bytes_written > MAX_FILE_BYTES

              tempfile.write(chunk)
            end
          end
        end

        response
      end
    rescue StandardError
      tempfile.close!
      raise
    end
  end
end
