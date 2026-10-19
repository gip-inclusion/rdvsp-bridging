module GoogleHelpers
  CALENDAR_API = "https://www.googleapis.com/calendar/v3".freeze

  def google_event(id:, starts_at: 1.day.from_now.change(hour: 8), ends_at: nil, **attrs)
    { "id" => id, "status" => "confirmed", "eventType" => "default",
      "start" => { "dateTime" => starts_at.iso8601 },
      "end" => { "dateTime" => (ends_at || (starts_at + 1.hour)).iso8601 }, }
      .merge(attrs.transform_keys(&:to_s))
  end

  def stub_google_token
    stub_request(:post, Google::Oauth::TOKEN_URL).to_return_json(body: { access_token: "access", expires_in: 3600 })
  end

  def stub_google_events(calendar_id, events, query: hash_including({}))
    stub_request(:get, "#{CALENDAR_API}/calendars/#{ERB::Util.url_encode(calendar_id)}/events").with(query:)
      .to_return_json(body: { items: events })
  end
end

RSpec.configure do |config|
  config.include GoogleHelpers
  config.around(:each, :google) do |example|
    previous = ENV.values_at("GOOGLE_CLIENT_ID", "GOOGLE_CLIENT_SECRET")
    ENV["GOOGLE_CLIENT_ID"] = "client-id"
    ENV["GOOGLE_CLIENT_SECRET"] = "client-secret"
    example.run
  ensure
    ENV["GOOGLE_CLIENT_ID"], ENV["GOOGLE_CLIENT_SECRET"] = previous
  end
end
