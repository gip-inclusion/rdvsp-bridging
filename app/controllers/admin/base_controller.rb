class Admin::BaseController < ApplicationController
  # Fails at boot in production when ADMIN_PASSWORD is missing (controllers are eager loaded)
  PASSWORD = Rails.env.local? ? ENV.fetch("ADMIN_PASSWORD", "admin") : ENV.fetch("ADMIN_PASSWORD")

  http_basic_authenticate_with name: "admin", password: PASSWORD
  layout "admin"
end
