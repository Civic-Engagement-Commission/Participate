# frozen_string_literal: true

require_relative "boot"

require "decidim/version"
require "decidim/rails"

# Add the frameworks used by your app that are not loaded by Decidim.
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_cable/engine"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module DecidimLite
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.1

    # Empêche Zeitwerk d'autoload le dossier decorators
    config.autoload_paths -= Rails.root.glob("app/decorators")
    config.eager_load_paths -= Rails.root.glob("app/decorators")

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    config.after_initialize do
      # Controllers
      require "extends/controllers/decidim/devise/omniauth_registrations_controller_extends"
      require "extends/controllers/decidim/errors_controller_extends"
    end
    # --- FORCE LE CHARGEMENT DES DÉCORATEURS ---
    # Chargement après initialisation complète de Rails
    config.after_initialize do
      decorators_path = Rails.root.join("app/decorators/**/*.rb")
      Dir[decorators_path].each do |decorator|
        Rails.logger.info "💡 Chargement manuel du décorateur : #{File.basename(decorator)}"
        require decorator
      end
    end
  end
end
