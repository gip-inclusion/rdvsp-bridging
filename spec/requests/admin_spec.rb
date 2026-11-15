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

  it "dresses the pages in the itou theme" do
    auth = ActionController::HttpAuthentication::Basic.encode_credentials("admin", "admin")

    get "/admin", headers: { "Authorization" => auth, "User-Agent" => browser }

    expect(response.body).to match(%r{/assets/stylesheets/app-\w+\.css}).and match(%r{/assets/pont-rdv-\w+\.css})
  end

  it "says when Pipedrive refuses the account's token instead of failing" do
    account = create(:account)
    stub_request(:get, "#{PipedriveHelpers::API}/v1/users").to_return(status: 401)
    auth = ActionController::HttpAuthentication::Basic.encode_credentials("admin", "admin")

    get "/admin/accounts/#{account.id}/connections/new", headers: { "Authorization" => auth, "User-Agent" => browser }

    expect(response).to redirect_to("/admin/accounts/#{account.id}")
    expect(flash[:alert]).to include("Pipedrive")
  end

  it "creates the link to send to an agent, on the configured base URL" do
    connection = create(:connection)
    headers = { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", "admin"),
                "User-Agent" => browser, "Host" => "evil.example", }

    get("/admin/connections/#{connection.id}", headers:)
    expect(response.body).to include("Créer un lien pour l’agent").and not_include("/agenda/")

    post("/admin/connections/#{connection.id}/caldav_link", headers:)
    follow_redirect!(headers:)
    expect(response.body).to include("http://localhost:3010/agenda/", "Créer un nouveau lien")
  end

  it "speaks French, durations included" do
    connection = create(:connection, last_seen_at: 5.minutes.ago)
    auth = ActionController::HttpAuthentication::Basic.encode_credentials("admin", "admin")

    get "/admin/connections/#{connection.id}", headers: { "Authorization" => auth, "User-Agent" => browser }

    expect(response.body).to include("Dernier passage de RDV-SP", "il y a 5 minutes")
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
