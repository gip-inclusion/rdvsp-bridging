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

  context "when RDVs that existed before were pushed anyway" do
    let!(:batch) do
      travel_to Time.utc(2026, 11, 10, 15, 15, 10)
      [create(:rdv, connection:, rdvsp_id: 1_182_824, provider_object_id: "65524", state: "synced", payload: nil),
       create(:rdv, connection:, rdvsp_id: 1_182_825, provider_object_id: "65522", state: "synced", payload: nil),]
    end
    let!(:booked_after) do
      travel_to Time.utc(2026, 11, 10, 15, 17, 40)
      create(:rdv, connection:, rdvsp_id: 1_259_524, provider_object_id: "65548", state: "synced", payload: nil)
    end

    it "previews the RDVs received before a cut-off, a minute after the first one by default" do
      get("/admin/connections/#{connection.id}/ignored_rdvs/new", headers:)

      expect(response.body).to include("2026-11-10T16:16:10", "1182824", "1182825")
      expect(response.body).not_to include("1259524")
    end

    it "ignores them and removes their activities" do
      post("/admin/connections/#{connection.id}/ignored_rdvs", params: { before: "2026-11-10T16:16:10" }, headers:)

      expect(response).to redirect_to("/admin/connections/#{connection.id}")
      expect(batch.map { it.reload.ignored? }).to eq([true, true])
      expect(booked_after.reload).not_to be_ignored
      expect(PushRdvJob).to have_been_enqueued.twice
    end

    it "refuses a cut-off it can't read rather than taking every RDV" do
      post("/admin/connections/#{connection.id}/ignored_rdvs", params: { before: "demain" }, headers:)

      expect(response).to have_http_status(:bad_request)
      expect(connection.rdvs.ignored).to be_empty
    end
  end

  it "counts each connection's ignored RDVs on the account page" do
    create_list(:rdv, 2, connection:, ignored_at: Time.current, payload: nil)

    get("/admin/accounts/#{connection.account.id}", headers:)

    expect(response.body).to include("<th>Ignorés</th>").and match(%r{<td>2</td>\s*</tr>})
  end
end
