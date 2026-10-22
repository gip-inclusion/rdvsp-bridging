require "rails_helper"

RSpec.describe "Admin" do
  let(:browser) { "Mozilla/5.0 (Macintosh) AppleWebKit/605.1.15 Version/18.0 Safari/605.1.15" }

  it "rate limits requests, wrong passwords included" do
    wrong = ActionController::HttpAuthentication::Basic.encode_credentials("admin", "wrong")
    30.times { get "/admin", headers: { "Authorization" => wrong, "User-Agent" => browser } }
    expect(response).to have_http_status(:unauthorized)

    get "/admin", headers: { "Authorization" => wrong, "User-Agent" => browser }
    expect(response).to have_http_status(:too_many_requests)
  ensure
    Admin::BaseController::RATE_LIMIT_STORE.clear
  end

  it "builds the CalDAV URL from the configured base URL, not from the request's host" do
    connection = create(:connection)
    auth = ActionController::HttpAuthentication::Basic.encode_credentials("admin", "admin")

    get "/admin/connections/#{connection.id}",
        headers: { "Authorization" => auth, "User-Agent" => browser, "X-Forwarded-Host" => "evil.example" }

    expect(response.body).to include("http://localhost:3010#{connection.calendar_path}")
    expect(response.body).not_to include("evil.example")
  end
end
