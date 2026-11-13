require "rails_helper"

RSpec.describe "Admin: the Pipedrive activity type of an account's RDVs" do
  let(:headers) do
    { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", "admin"),
      "User-Agent" => "Mozilla/5.0 (Macintosh) AppleWebKit/605.1.15 Version/18.0 Safari/605.1.15", }
  end
  let(:account) { create(:account, rdv_activity_type_key: "rdv_service_public") }
  let(:path) { "/admin/accounts/#{account.id}/rdv_activity_type" }
  let(:types_url) { "#{PipedriveHelpers::API}/v1/activityTypes" }

  it "chooses one of the company's active types" do
    types = [{ name: "RDV Service Public", key_string: "rdv_service_public", active_flag: true },
             { name: "RDV Individuel", key_string: "rdv_individuel", active_flag: true },
             { name: "Ancien type", key_string: "ancien", active_flag: false },]
    stub_request(:get, types_url).to_return_json(body: { success: true, data: types })

    get "#{path}/edit", headers: headers
    expect(response.body).to include("RDV Individuel")
    expect(response.body).not_to include("Ancien type")

    patch path, params: { key: "rdv_individuel" }, headers: headers
    expect(response).to redirect_to("/admin/accounts/#{account.id}")
    expect(account.reload.rdv_activity_type_key).to eq("rdv_individuel")
  end

  it "creates a new type in Pipedrive" do
    create_type = stub_request(:post, types_url).with(body: { name: "Rendez-vous", icon_key: "calendar" })
      .to_return_json(body: { success: true, data: { name: "Rendez-vous", key_string: "rendez_vous" } })

    patch path, params: { key: "rdv_service_public", name: " Rendez-vous " }, headers: headers

    expect(create_type).to have_been_requested
    expect(account.reload.rdv_activity_type_key).to eq("rendez_vous")
  end

  it "says when Pipedrive fails" do
    stub_request(:get, types_url).to_return(status: 500)

    get "#{path}/edit", headers: headers

    expect(response).to redirect_to("/admin/accounts/#{account.id}")
  end
end
