require "rails_helper"

RSpec.describe "Google provider", :google do
  let(:account) { create(:account, provider: "google", api_token: "refresh", refresh_cursor: 10.minutes.ago) }
  let!(:connection) { create(:connection, account:, provider_user_id: "primary") }

  before { stub_google_token }

  it "refreshes incrementally, removing cancelled events" do
    connection.upsert_busy_block!("gone", starts_at: 1.day.from_now, ends_at: 1.day.from_now + 1.hour)
    request = stub_google_events("primary", [google_event(id: "new"), google_event(id: "gone", status: "cancelled")],
                                 query: hash_including("singleEvents" => "true", "showDeleted" => "true"))

    expect(Google::RefreshAccount.call(account:)).to be_success

    expect(request).to have_been_requested
    expect(connection.busy_blocks.live.pluck(:provider_object_id)).to eq(["new"])
    expect(account.reload.access_token).to eq("access")
  end

  it "rebuilds a calendar from its expanded events" do
    connection.upsert_busy_block!("old", starts_at: 1.day.from_now, ends_at: 1.day.from_now + 1.hour)
    stub_google_events("primary",
                       [google_event(id: "a_20261021T080000Z"), google_event(id: "b", transparency: "transparent")])

    expect(Google::RebuildConnection.call(connection:).count).to eq(1)
    expect(connection.busy_blocks.live.pluck(:provider_object_id)).to eq(["a_20261021T080000Z"])
  end

  it "records a revoked grant as a failure" do
    stub_request(:post, Google::Oauth::TOKEN_URL).to_return(status: 400, body: { error: "invalid_grant" }.to_json)

    expect(Google::RefreshAccount.call(account:)).to be_failure
    expect(account.reload.last_error).to include("invalid_grant")
  end

  describe Google::PushRdv do
    let(:rdv) { create(:rdv, connection:, payload: { "summary" => "Jeanne Dupont - Accueil", "description" => "" }) }
    let(:events_url) { "#{GoogleHelpers::CALENDAR_API}/calendars/primary/events" }

    it "inserts a minimal, opaque event tagged as ours" do
      insert = stub_request(:post, events_url).with(body: hash_including(
        "summary" => "RDV Service Public", "transparency" => "opaque",
        "extendedProperties" => { "private" => { "rdvsp_bridging_rdv" => rdv.href_name } }
      )).to_return_json(body: { id: "evt1" })

      described_class.call(rdv:)

      expect(insert).to have_been_requested
      expect(rdv.reload).to have_attributes(provider_object_id: "evt1", state: "synced", payload: nil)
    end

    it "deletes the event of a cancelled RDV, tolerating 410" do
      rdv.update!(provider_object_id: "evt1", cancelled_at: Time.current)
      stub_request(:delete, "#{events_url}/evt1").to_return(status: 410)

      described_class.call(rdv:)

      expect(rdv.reload.state).to eq("synced")
    end
  end

  describe Google::Connect do
    let(:id_token) do
      ["x", Base64.urlsafe_encode64({ sub: "123", email: "agent@example.fr" }.to_json), "sig"].join(".")
    end

    it "creates the account and connects the primary calendar" do
      stub_request(:post, Google::Oauth::TOKEN_URL).with(body: hash_including("grant_type" => "authorization_code"))
        .to_return_json(body: { access_token: "a", refresh_token: "r", expires_in: 3600, id_token: })

      result = described_class.call(code: "code", redirect_uri: "http://localhost/cb")

      expect(result.account).to have_attributes(provider: "google", provider_company_id: "123",
                                                name: "agent@example.fr", api_token: "r")
      expect(result.connection).to have_attributes(provider_user_id: "primary", provider_user_name: "agent@example.fr")
      expect(result.password).to be_present
    end
  end
end
