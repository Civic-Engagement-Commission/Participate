# frozen_string_literal: true

module Decidim
  module AttachmentOverride
    extend ActiveSupport::Concern

    included do
      alias_method :original_file_type, :file_type

      def file_type
        return file.blob.content_type.split("/").last.upcase if file.attached? && file.respond_to?(:blob)
        return content_type.split("/").last.upcase if respond_to?(:content_type) && content_type.present?

        "UNKNOWN"
      rescue StandardError => e
        Rails.logger.warn("[Decidim::Attachment#file_type override] #{e.class}: #{e.message}")
        "UNKNOWN"
      end
    end
  end
end
