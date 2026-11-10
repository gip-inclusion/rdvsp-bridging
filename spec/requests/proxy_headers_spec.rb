require "rails_helper"

RSpec.describe "Requests through Scaleway's load balancers" do
  # As received in production on 2026-11-10: Scaleway's hops are in 100.64.0.0/10, and `Forwarded` lacks the last one
  let(:proxy_headers) do
    { "X-Forwarded-For" => "34.250.16.92, 100.96.32.53, 100.96.50.112",
      "Forwarded" => "for=34.250.16.92;proto=https, for=100.96.32.53", }
  end

  it "takes the client's address from the forwarding headers instead of calling them a spoofing attack" do
    connection = create(:connection, password: "pw")
    connection.account.update!(refreshed_at: Time.current)
    auth = ActionController::HttpAuthentication::Basic.encode_credentials(connection.username, "pw")

    process :propfind, connection.calendar_path, headers: proxy_headers.merge("Depth" => "0", "Authorization" => auth)

    expect(response).to have_http_status(:multi_status)
    expect(request.remote_ip).to eq("34.250.16.92")
  end
end
