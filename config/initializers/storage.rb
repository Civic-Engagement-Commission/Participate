# frozen_string_literal: true

require "aws-sdk-core"

Aws.config.update(credentials: Aws::ECSCredentials.new) if Rails.env.production? && Rails.application.config.active_storage.service == :amazon_instance_profile

# Prevent cascading failures when S3 is inaccessible during error handling
if defined?(Decidim::MetaImageUrlResolver)
  Decidim::MetaImageUrlResolver.class_eval do
    def resolve_with_error_handling
      resolve_without_error_handling
    rescue Aws::S3::Errors::Forbidden, Aws::S3::Errors::ServiceError => e
      Rails.logger.warn "S3 error during meta image resolution: #{e.class} - #{e.message}"
      nil
    end

    alias_method :resolve_without_error_handling, :resolve
    alias_method :resolve, :resolve_with_error_handling
  end
end
