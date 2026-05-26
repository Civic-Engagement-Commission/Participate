# frozen_string_literal: true

require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  # Ensures that a master key has been made available in ENV["RAILS_MASTER_KEY"], config/master.key, or an environment
  # key such as config/credentials/production.key. This key is used to decrypt credentials (and other encrypted files).
  # config.require_master_key = true

  # Disable serving static files from the `/public` folder by default since
  # Apache or NGINX already handles this.
  config.public_file_server.enabled = ENV["RAILS_SERVE_STATIC_FILES"].present?

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  config.asset_host = ENV["RAILS_ASSET_HOST"] if ENV["RAILS_ASSET_HOST"].present?

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = Decidim::Env.new("STORAGE_PROVIDER", "local").to_s.to_sym

  # Expiration for ActiveStorage signed URLs (NYC backport — keeps S3 image URLs alive longer).
  config.active_storage.service_urls_expire_in = Decidim::Env.new("DECIDIM_SERVICE_URLS_EXPIRES_IN", "1").to_i.days

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = Decidim::Env.new("DECIDIM_FORCE_SSL", "auto").default_or_present_if_exists.to_s == "auto" ? true : Decidim::Env.new("DECIDIM_FORCE_SSL").present?

  # Skip http-to-https redirect for the Rails built-in /up health check endpoint.
  config.ssl_options = if config.force_ssl
                         { redirect: { exclude: ->(request) { request.path == "/up" } } }
                       else
                         { redirect: false }
                       end

  if ENV["RAILS_LOG_TO_STDOUT"].present?
    config.logger = ActiveSupport::Logger.new($stdout)
                                         .tap { |logger| logger.formatter = Logger::Formatter.new }
                                         .then { |logger| ActiveSupport::TaggedLogging.new(logger) }
  end

  # Include generic and useful information about system operation, but avoid logging too much
  # information to avoid inadvertent exposure of personally identifiable information (PII).
  config.log_level = %w(debug info warn error fatal).include?(ENV["RAILS_LOG_LEVEL"]) ? ENV["RAILS_LOG_LEVEL"].to_sym : :info

  # Prepend all log lines with the following tags.
  config.log_tags = [:request_id, :ip]

  # Use a different cache store in production (memcached via dalli gem).
  config.cache_store = :mem_cache_store, ENV.fetch("MEMCACHE_SERVERS", "localhost:11211")

  # Use a real queuing backend for Active Job (and separate queues per environment).
  config.active_job.queue_adapter = ENV.fetch("QUEUE_ADAPTER", "sidekiq").to_sym
  # config.active_job.queue_name_prefix = "decidim_nyc_production"

  # Disable caching for Action Mailer templates even if Action Controller caching is enabled.
  config.action_mailer.perform_caching = false

  # Mailer setup: letter_opener_web for staging / dev-like envs, SMTP for real production.
  if ENV.fetch("ENABLE_LETTER_OPENER", "0") == "1"
    config.action_mailer.delivery_method = :letter_opener_web
    config.action_mailer.default_url_options = { port: 3000 }
  else
    # Prevent mailer from crashing on seeds with missing SMTP config.
    config.action_mailer.raise_delivery_errors = false

    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      address: Decidim::Env.new("SMTP_ADDRESS").to_s,
      port: Decidim::Env.new("SMTP_PORT", 587).to_i,
      authentication: Decidim::Env.new("SMTP_AUTHENTICATION", "plain").to_s,
      user_name: Decidim::Env.new("SMTP_USERNAME").to_s,
      password: Decidim::Env.new("SMTP_PASSWORD").to_s,
      domain: Decidim::Env.new("SMTP_DOMAIN").to_s,
      enable_starttls_auto: Decidim::Env.new("SMTP_STARTTLS_AUTO", true).present?,
      openssl_verify_mode: "none"
    }
  end

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [:id]

  # Enable DNS rebinding protection and other `Host` header attacks.
  # config.hosts = [
  #   "example.com",
  #   /.*\.example\.com/
  # ]
  # Skip DNS rebinding protection for the default health check endpoint.
  # config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
