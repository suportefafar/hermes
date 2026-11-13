require_relative "boot"
require_relative "../lib/hermes_encryption"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
# require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Hermes
  class Application < Rails::Application
    config.load_defaults 8.1

    config.autoload_lib(ignore: %w[assets tasks])

    config.generators.system_tests = nil

    config.time_zone = "Brasilia"

    # Background jobs via Solid Queue
    config.active_job.queue_adapter = :solid_queue
    config.solid_queue.connects_to = { database: { writing: :queue } }

    # Cache store via Solid Cache
    config.cache_store = :solid_cache_store

    # Autoload app/services
    config.autoload_paths << Rails.root.join("app/services")

    # Rack::Attack for API protection
    config.middleware.use Rack::Attack

    # Disable ActiveStorage variant processor since we don't need image variants
    config.active_storage.variant_processor = :disabled

    asset_build = defined?(Rake) && Rake.application.top_level_tasks == [ "assets:precompile" ]
    HermesEncryption.keys(ENV, asset_build: asset_build).each do |name, value|
      config.active_record.encryption.public_send("#{name}=", value)
    end
  end
end
