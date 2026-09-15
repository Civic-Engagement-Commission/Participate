# frozen_string_literal: true

rails_env = ENV.fetch("RAILS_ENV", "development")

# Puma can serve each request in a thread from an internal thread pool.
# The `threads` method setting takes two numbers: a minimum and maximum.
# Any libraries that use thread pools should be configured to match
# the maximum value specified for Puma. Default is set to 5 threads for minimum
# and maximum; this matches the default thread size of Active Record.
max_threads = ENV.fetch("RAILS_MAX_THREADS", 5).to_i
min_threads = ENV.fetch("RAILS_MIN_THREADS", max_threads).to_i

threads min_threads, max_threads

environment rails_env
port ENV.fetch("PORT", 3000)
pidfile ENV.fetch("PIDFILE", "tmp/puma.pid")

# Specifies the `worker_timeout` threshold that Puma will use to wait before
# terminating a worker in development environments.
worker_timeout 3600 if rails_env == "development"

if rails_env == "production"
  workers ENV.fetch("WEB_CONCURRENCY", 2).to_i
  preload_app!

  on_worker_boot do
    SemanticLogger.reopen if defined?(SemanticLogger)
  end
else
  # Development SSL
  if ENV.fetch("DEV_SSL", nil) && defined?(Bundler) && (dev_gem = Bundler.load.specs.find { |spec| spec.name == "decidim-dev" })
    cert_dir = ENV.fetch("DEV_SSL_DIR") { "#{dev_gem.full_gem_path}/lib/decidim/dev/assets" }
    ssl_bind(
      "0.0.0.0",
      ENV.fetch("DEV_SSL_PORT", 3443),
      cert_pem: File.read("#{cert_dir}/ssl-cert.pem"),
      key_pem: File.read("#{cert_dir}/ssl-key.pem")
    )
  end

  # Allow puma to be restarted by `rails restart` command.
  plugin :tmp_restart
end
