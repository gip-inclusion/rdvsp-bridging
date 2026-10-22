require "rails_helper"

RSpec.describe "CalDAV server" do
  let(:connection) { create(:connection, password: "pw-#{SecureRandom.hex}") }
  let(:other) { create(:connection, password: "other-password") }
  let(:auth) { ActionController::HttpAuthentication::Basic.encode_credentials(connection.username, connection.password) }

  before { connection.account.update!(refreshed_at: Time.current) }

  it "requires credentials" do
    process :propfind, connection.calendar_path, headers: { "Depth" => "0" }

    expect(response).to have_http_status(:unauthorized)
  end

  it "throttles repeated wrong passwords for a username" do
    CaldavController::FAILED_AUTHENTICATIONS.clear
    wrong = ActionController::HttpAuthentication::Basic.encode_credentials(connection.username, "wrong")
    10.times { process :propfind, connection.calendar_path, headers: { "Depth" => "0", "Authorization" => wrong } }
    expect(response).to have_http_status(:unauthorized)

    process :propfind, connection.calendar_path, headers: { "Depth" => "0", "Authorization" => auth }
    expect(response).to have_http_status(:too_many_requests)
  ensure
    CaldavController::FAILED_AUTHENTICATIONS.clear
  end

  it "hides other connections' calendars" do
    process :propfind, other.calendar_path, headers: { "Depth" => "0", "Authorization" => auth }

    expect(response).to have_http_status(:not_found)
  end

  it "refuses unparseable events" do
    put "#{connection.calendar_path}abc.ics", params: "not ics", headers: { "Authorization" => auth }

    expect(response).to have_http_status(:bad_request)
  end

  it "answers 404 when deleting an unknown event, as RDV-SP tolerates" do
    delete "#{connection.calendar_path}unknown.ics", headers: { "Authorization" => auth }

    expect(response).to have_http_status(:not_found)
  end

  it "refreshes the provider data before answering a REPORT when it is stale" do
    connection.account.update!(refreshed_at: 5.minutes.ago)
    allow(Pipedrive::RefreshAccount).to receive(:call)
    body = '<d:sync-collection xmlns:d="DAV:"><d:sync-token/><d:sync-level>1</d:sync-level></d:sync-collection>'

    process :report, connection.calendar_path, params: body, headers: { "Authorization" => auth }

    expect(response).to have_http_status(:multi_status)
    expect(Pipedrive::RefreshAccount).to have_received(:call)
  end

  it "records when RDV-SP last came" do
    process :propfind, connection.calendar_path, headers: { "Depth" => "0", "Authorization" => auth }

    expect(connection.reload.last_seen_at).to be_present
  end
end
