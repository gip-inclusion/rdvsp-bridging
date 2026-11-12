require "rails_helper"

RSpec.describe "Admin: RDV-SP usager import", :rdvsp do
  let(:headers) do
    { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", "admin"),
      "User-Agent" => "Mozilla/5.0 (Macintosh) AppleWebKit/605.1.15 Version/18.0 Safari/605.1.15", }
  end
  let(:account) { create(:account) }
  let(:preview_params) { { organisation_id: 42, field: "abc123:34", active_since: "2025-01-01" } }

  def stub_pipedrive_fields
    stub_request(:get, "#{PipedriveHelpers::API}/v1/personFields").with(query: hash_including({}))
      .to_return_json(body: { success: true, data: [{ key: "abc123", name: "Type", field_type: "set",
                                                      options: [{ id: 34, label: "Accompagnée" }], }], })
  end

  it "hides the RDV-SP section while the OAuth application isn't configured" do
    ENV["RDVSP_URL"] = nil

    get "/admin/accounts/#{account.id}", headers: headers

    expect(response.body).not_to include("RDV Service Public")
  end

  it "gives the authorization link to send, then who authorized and the imports" do
    get "/admin/accounts/#{account.id}", headers: headers
    expect(response.body).to include("Aucun agent", "#{Rails.configuration.x.base_url}/rdvsp/authorize/")

    create(:rdvsp_authorization, account:, agent_email: "paul@example.fr")
    create(:usager_import, account:, state: "done", counts: { "created" => 12, "rejected" => 1 })
    get "/admin/accounts/#{account.id}", headers: headers
    expect(response.body).to include("paul@example.fr", "Importer des bénéficiaires", "12 créés", "1 refusé")
  end

  it "previews an import with counts only" do
    create(:rdvsp_authorization, account:)
    stub_rdvsp_organisations([{ id: 42, name: "Massajobs Paris" }])
    stub_rdvsp_organisation_users(42, [])
    stub_pipedrive_fields
    stub_pipedrive_persons([pipedrive_person(1), pipedrive_person(2, first_name: nil)])

    get "/admin/accounts/#{account.id}/usager_imports/new", params: preview_params, headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Massajobs Paris", "Type → Accompagnée", "Importer 1 usager")
    expect(response.body).not_to include("Lovelace")
  end

  it "starts the import in the background" do
    create(:rdvsp_authorization, account:)

    expect { post "/admin/accounts/#{account.id}/usager_imports", params: preview_params, headers: headers }
      .to have_enqueued_job(ImportUsagersJob)

    expect(account.usager_imports.sole).to have_attributes(rdvsp_organisation_id: 42, field_key: "abc123",
                                                           option_id: "34", active_since: Date.new(2025, 1, 1))
    expect(response).to redirect_to("/admin/accounts/#{account.id}")
  end

  it "withdraws the authorization, revoking its token at RDV-SP" do
    create(:rdvsp_authorization, account:, refresh_token: "refresh")
    revoke = stub_request(:post, "#{rdvsp_url}/oauth/revoke").with(body: hash_including(token: "refresh"))

    delete "/admin/accounts/#{account.id}/rdvsp_authorization", headers: headers

    expect(revoke).to have_been_requested
    expect(account.reload.rdvsp_authorization).to be_nil
  end
end
