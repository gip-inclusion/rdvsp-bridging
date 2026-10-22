class Admin::BaseController < ApplicationController
  # Fails at boot in production when ADMIN_PASSWORD is missing (controllers are eager loaded)
  PASSWORD = Rails.env.local? ? ENV.fetch("ADMIN_PASSWORD", "admin") : ENV.fetch("ADMIN_PASSWORD")
  RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new

  # Before authentication, so that wrong passwords count too
  rate_limit to: 30, within: 1.minute, store: RATE_LIMIT_STORE
  http_basic_authenticate_with name: "admin", password: PASSWORD
  layout "admin"
end
