# frozen_string_literal: true

# Patch pour corriger la méthode file_type dans Decidim::Attachment
# afin d'afficher le bon type MIME sans les query params AWS S3.

# app/decorators/decidim/attachment_patch.rb

module Decidim
  module AttachmentPatch
  end
end

Rails.logger.info "Patch chargé : Decidim::Attachment#file_type"

Decidim::Attachment.class_eval do
  def file_type
    return file.blob.content_type.split("/").last.upcase if file.attached? && file.respond_to?(:blob)

    return content_type.split("/").last.upcase if respond_to?(:content_type) && content_type.present?

    "UNKNOWN"
  rescue StandardError => e
    Rails.logger.warn("[Attachment#file_type patch] #{e.class}: #{e.message}")
    "UNKNOWN"
  end
end
