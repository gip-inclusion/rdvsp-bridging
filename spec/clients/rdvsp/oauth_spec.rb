require "rails_helper"

RSpec.describe Rdvsp::Oauth, :rdvsp do
  let(:redirect_uri) { "https://bridge.example.fr/rdvsp/callback" }

  it "is configured only when the URL, the client id and the secret are all set" do
    expect(described_class).to be_configured
    ENV["RDVSP_OAUTH_CLIENT_SECRET"] = nil
    expect(described_class).not_to be_configured
  end

  it "sends the agent to RDV-SP's authorization page" do
    url = URI(described_class.authorize_url(redirect_uri:, state: "xyz"))

    expect(url.to_s).to start_with("#{rdvsp_url}/oauth/authorize?")
    expect(Rack::Utils.parse_query(url.query))
      .to eq("client_id" => "client-id", "redirect_uri" => redirect_uri, "response_type" => "code", "state" => "xyz")
  end

  it "exchanges the code for tokens" do
    token = stub_rdvsp_token.with(body: { grant_type: "authorization_code", code: "abc", redirect_uri:,
                                          client_id: "client-id", client_secret: "client-secret", })

    freeze_time do
      expect(described_class.exchange_code(code: "abc", redirect_uri:))
        .to eq(access_token: "new-access", refresh_token: "new-refresh", expires_at: 2.hours.from_now)
    end
    expect(token).to have_been_requested
  end

  it "refreshes the tokens" do
    stub_rdvsp_token.with(body: hash_including(grant_type: "refresh_token", refresh_token: "old-refresh"))

    expect(described_class.refresh("old-refresh")).to include(access_token: "new-access", refresh_token: "new-refresh")
  end

  it "tells a refused grant from a server error" do
    stub_request(:post, "#{rdvsp_url}/oauth/token").to_return_json(status: 400, body: { error: "invalid_grant" })
    expect { described_class.refresh("old") }.to raise_error(Rdvsp::AuthenticationError, /invalid_grant/)

    stub_request(:post, "#{rdvsp_url}/oauth/token").to_return(status: 502, body: "Bad gateway")
    expect { described_class.refresh("old") }.to raise_error(Rdvsp::Error, /502/) { expect(it).not_to be_a(Rdvsp::AuthenticationError) }
  end

  it "revokes a token" do
    revoke = stub_request(:post, "#{rdvsp_url}/oauth/revoke")
      .with(body: { token: "refresh", client_id: "client-id", client_secret: "client-secret" })

    described_class.revoke("refresh")

    expect(revoke).to have_been_requested
  end
end
