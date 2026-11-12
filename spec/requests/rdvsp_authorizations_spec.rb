require "rails_helper"

RSpec.describe "RDV-SP authorization by a partner's agent", :rdvsp do
  let(:browser) { { "User-Agent" => "Mozilla/5.0 (Macintosh) AppleWebKit/605.1.15 Version/18.0 Safari/605.1.15" } }
  let(:account) { create(:account, name: "Massajobs") }
  let(:token) { account.signed_id(purpose: :rdvsp_authorization, expires_in: 7.days) }
  let(:redirect_uri) { "#{Rails.configuration.x.base_url}/rdvsp/callback" }

  def start_authorization
    post "/rdvsp/authorize/#{token}", headers: browser
    Rack::Utils.parse_query(URI(response.location).query).fetch("state")
  end

  it "explains what the agent authorizes before sending them to RDV-SP" do
    get "/rdvsp/authorize/#{token}", headers: browser

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Massajobs", "créer des usagers", "Continuer vers RDV Service Public")
  end

  it "refuses an expired or tampered link" do
    expired = token
    travel 8.days do
      get "/rdvsp/authorize/#{expired}", headers: browser
      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("Ce lien n’est plus valable")
    end

    post "/rdvsp/authorize/#{token}x", headers: browser
    expect(response).to have_http_status(:not_found)
  end

  it "sends the agent to RDV-SP with a state, and stores the tokens and the agent when they come back" do
    state = start_authorization
    expect(response.location).to start_with("#{rdvsp_url}/oauth/authorize?")
    expect(Rack::Utils.parse_query(URI(response.location).query)).to include("redirect_uri" => redirect_uri)

    stub_rdvsp_token(access_token: "access", refresh_token: "refresh")
      .with(body: hash_including(grant_type: "authorization_code", code: "abc", redirect_uri:))
    stub_rdvsp_me(id: 77, email: "paul@example.fr").with(headers: { "Authorization" => "Bearer access" })

    get "/rdvsp/callback", params: { code: "abc", state: }, headers: browser

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("C’est fait")
    expect(account.reload.rdvsp_authorization).to have_attributes(agent_id: 77, agent_email: "paul@example.fr",
                                                                  access_token: "access", refresh_token: "refresh")
  end

  it "replaces an earlier authorization, revoking its token at RDV-SP" do
    create(:rdvsp_authorization, account:, refresh_token: "old-refresh", lost_at: 1.day.ago)
    revoke = stub_request(:post, "#{rdvsp_url}/oauth/revoke").with(body: hash_including(token: "old-refresh"))
    stub_rdvsp_token
    stub_rdvsp_me(id: 78)

    get "/rdvsp/callback", params: { code: "abc", state: start_authorization }, headers: browser

    expect(account.reload.rdvsp_authorization).to have_attributes(agent_id: 78, lost_at: nil)
    expect(revoke).to have_been_requested
  end

  it "refuses a callback without the state it sent" do
    start_authorization

    get "/rdvsp/callback", params: { code: "abc", state: "forged" }, headers: browser

    expect(response).to have_http_status(:bad_request)
    expect(account.reload.rdvsp_authorization).to be_nil
  end

  it "tells the agent when they declined" do
    get "/rdvsp/callback", params: { error: "access_denied", state: start_authorization }, headers: browser

    expect(response.body).to include("Vous n’avez pas autorisé")
    expect(account.reload.rdvsp_authorization).to be_nil
  end

  it "hides the page while RDV-SP's OAuth application isn't configured" do
    ENV["RDVSP_OAUTH_CLIENT_ID"] = nil

    get "/rdvsp/authorize/#{token}", headers: browser

    expect(response).to have_http_status(:not_found)
  end
end
