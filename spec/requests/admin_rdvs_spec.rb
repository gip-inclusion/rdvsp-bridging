require "rails_helper"

RSpec.describe "Admin: a connection's RDVs" do
  let(:connection) { create(:connection) }
  let(:headers) do
    { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", "admin"),
      "User-Agent" => "Mozilla/5.0 (Macintosh) AppleWebKit/605.1.15 Version/18.0 Safari/605.1.15", }
  end

  it "lists the latest RDVs by RDV-SP id, received time (Paris) and status, never their content" do
    travel_to Time.utc(2026, 11, 10, 15, 15, 10)
    create(:rdv, connection:, rdvsp_id: 1_182_824, ignored_at: Time.current, payload: nil, state: "synced")
    create(:rdv, connection:, rdvsp_id: 1_259_524, provider_object_id: "65548", state: "pending",
                 payload: { "summary" => "Jeanne Dupont - Accueil" })

    get("/admin/connections/#{connection.id}", headers:)

    expect(response.body).to include("transmis : 1", "ignorés : 1", "1182824", "1259524", "10/11/2026 16:15:10")
    expect(response.body).not_to include("Jeanne Dupont")
  end

  it "releases an ignored RDV, to be pushed at RDV-SP's next PUT of it" do
    rdv = create(:rdv, connection:, ignored_at: Time.current, payload: nil, state: "synced")

    post("/admin/rdvs/#{rdv.id}/release", headers:)

    expect(response).to redirect_to("/admin/connections/#{connection.id}")
    expect(rdv.reload).not_to be_ignored
    expect(PushRdvJob).not_to have_been_enqueued
  end

  it "counts each connection's ignored RDVs on the account page" do
    create_list(:rdv, 2, connection:, ignored_at: Time.current, payload: nil)

    get("/admin/accounts/#{connection.account.id}", headers:)

    expect(response.body).to include("<th>Ignorés</th>").and match(%r{<td>2</td>\s*</tr>})
  end
end
