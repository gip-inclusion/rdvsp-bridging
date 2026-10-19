class Admin::BaseController < ApplicationController
  http_basic_authenticate_with name: "admin", password: ENV.fetch("ADMIN_PASSWORD") { Rails.env.local? ? "admin" : nil }
  layout "admin"
end
