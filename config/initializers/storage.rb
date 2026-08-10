# frozen_string_literal: true

require "aws-sdk-core"

Aws.config.update(credentials: Aws::ECSCredentials.new) if Rails.env.production? && Rails.application.config.active_storage.service == :amazon_instance_profile
