# frozen_string_literal: true

return unless defined?(Sidekiq)

redis_h = {
  network_timeout: 10,
  pool_timeout: 10,
  reconnect_attempts: 0
}

Sidekiq.configure_client do |config|
  config.redis = redis_h
end
