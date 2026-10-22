require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
# require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
# require "action_cable/engine"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module RdvspBridging
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Don't generate system test files.
    config.generators.system_tests = nil
    config.generators.test_framework :rspec

    config.active_job.queue_adapter = :good_job
    config.good_job.execution_mode = :async
    config.good_job.enable_cron = true
    config.good_job.cron = {
      refresh_accounts: { cron: "*/5 * * * *", class: "RefreshAccountsJob" },
      rebuild_connections: { cron: "17 * * * *", class: "RebuildConnectionsJob" },
      check_health: { cron: "*/30 * * * *", class: "CheckHealthJob" },
    }

    config.active_record.encryption.primary_key = ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"]
    config.active_record.encryption.deterministic_key = ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"]
    config.active_record.encryption.key_derivation_salt = ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"]

    config.i18n.default_locale = :fr

    # Public URL of the bridge, for the CalDAV URLs, webhooks and OAuth redirects (never the request's Host header)
    config.x.base_url = ENV.fetch("BRIDGE_BASE_URL", "http://localhost:3010").delete_suffix("/")
  end
end
