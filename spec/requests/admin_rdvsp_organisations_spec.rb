require "rails_helper"

RSpec.describe "Admin: the RDV-SP organisation of an account's usagers", :rdvsp do
  let(:headers) do
    { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", "admin"),
      "User-Agent" => "Mozilla/5.0 (Macintosh) AppleWebKit/605.1.15 Version/18.0 Safari/605.1.15", }
  end
  let(:account) { create(:account) }

  before { create(:rdvsp_authorization, account:) }

  it "shows the account's organisation, or that none was chosen" do
    get "/admin/accounts/#{account.id}", headers: headers
    expect(response.body).to include("pas encore choisie")

    account.update!(rdvsp_organisation_id: 42)
    get "/admin/accounts/#{account.id}", headers: headers
    expect(response.body).to include("n° 42")
  end

  it "chooses it among the agent's organisations" do
    stub_rdvsp_organisations([{ id: 41, name: "Antenne Lyon" }, { id: 42, name: "Antenne Paris" }])

    get "/admin/accounts/#{account.id}/rdvsp_organisation/edit", headers: headers
    expect(response.body).to include("Antenne Lyon", "Antenne Paris")

    patch "/admin/accounts/#{account.id}/rdvsp_organisation", params: { organisation_id: 41 }, headers: headers
    expect(response).to redirect_to("/admin/accounts/#{account.id}")
    expect(account.reload.rdvsp_organisation_id).to eq(41)
  end

  it "sends back to the account when RDV-SP fails" do
    stub_request(:get, "#{rdvsp_url}/api/v1/organisations").with(query: hash_including({})).to_return(status: 500)

    get "/admin/accounts/#{account.id}/rdvsp_organisation/edit", headers: headers

    expect(response).to redirect_to("/admin/accounts/#{account.id}")
    expect(flash[:alert]).to start_with("Organisations indisponibles")
  end
end
