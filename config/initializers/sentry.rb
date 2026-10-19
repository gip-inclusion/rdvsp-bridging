if ENV["SENTRY_DSN"].present?
  Sentry.init do |config|
    config.dsn = ENV["SENTRY_DSN"]
    config.environment = ENV.fetch("SENTRY_ENVIRONMENT", Rails.env)
    config.breadcrumbs_logger = %i[active_support_logger http_logger]
    # Request bodies (iCalendar from RDV-SP) can contain usager personal data
    config.send_default_pii = false
    config.traces_sample_rate = 0
  end
end
