require "rails_helper"

RSpec.describe "Pipedrive app: the Prendre RDV button and the installation", :pipedrive_app, :rdvsp do
  let(:browser) { { "User-Agent" => "Mozilla/5.0 (Macintosh) AppleWebKit/605.1.15 Version/18.0 Safari/605.1.15" } }
  let(:account) { create(:account, provider_company_id: "13579", provider_company_domain: "acme") }
  let(:callback_url) { "#{Rails.configuration.x.base_url}/pipedrive/app/callback" }

  def click(token: pipedrive_click_token(company_id: 13_579), **params)
    get "/pipedrive/prendre-rdv", headers: browser, params: {
      resource: "person", view: "details", userId: 501, companyId: 13_579, selectedIds: "7", token:, **params,
    }
  end

  describe "Prendre RDV" do
    before { create(:rdvsp_authorization, account:, provider_user_id: "501") }

    it "opens an RDV plan in RDV-SP, which leads back to the person in Pipedrive" do
      create(:imported_usager, account:, provider_person_id: "7", rdvsp_user_id: 99)
      return_url = nil
      stub_request(:post, "#{rdvsp_url}/api/v1/rdv_plans")
        .with { return_url = JSON.parse(it.body)["return_url"] }
        .to_return_json(status: 201, body: { rdv_plan: { id: 5, url: "#{rdvsp_url}/agents/rdv_plans/5" } })

      click

      expect(response).to redirect_to("#{rdvsp_url}/agents/rdv_plans/5")
      expect(return_url).to start_with("#{Rails.configuration.x.base_url}/pipedrive/retour/")
      get URI(return_url).path, headers: browser
      expect(response).to redirect_to("https://acme.pipedrive.com/person/7")
    end

    it "explains why it can't, in words the agent can act on" do
      stub_rdvsp_organisations([{ id: 41, name: "Antenne Lyon" }, { id: 42, name: "Antenne Paris" }])

      click

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("dans quelle organisation")
    end

    it "trusts the company of the signed token, not the one in the URL" do
      create(:account, provider_company_id: "24680")

      click(token: pipedrive_click_token(company_id: 24_680), companyId: 13_579)

      expect(response.body).to include("Autoriser Pont RDV")
    end

    it "refuses a click Pipedrive didn't sign, or from an unknown company" do
      click(token: pipedrive_click_token(secret: "other"))
      expect(response).to have_http_status(:unauthorized)
      expect(response.body).to include("Ce lien ne vient pas de Pipedrive")

      click(token: pipedrive_click_token(company_id: 1))
      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("pas activé")
    end

    it "wants exactly one person" do
      click(selectedIds: "7,8")
      expect(response).to have_http_status(:bad_request)

      click(resource: "deal")
      expect(response).to have_http_status(:bad_request)
    end

    it "says so when RDV-SP fails, or refuses the agent" do
      create(:imported_usager, account:, provider_person_id: "7", rdvsp_user_id: 99)
      stub_request(:post, "#{rdvsp_url}/api/v1/rdv_plans").to_return(status: 500)

      click
      expect(response).to have_http_status(:bad_gateway)

      stub_request(:post, "#{rdvsp_url}/api/v1/rdv_plans").to_return_json(status: 403, body: {})
      click
      expect(response).to have_http_status(:forbidden)
      expect(response.body).to include("vous y ajouter")
    end
  end

  describe "an agent's first click" do
    let(:plan_url) { "#{rdvsp_url}/agents/rdv_plans/5" }

    before do
      create(:rdvsp_authorization, account:, access_token: "import-access")
      create(:imported_usager, account:, provider_person_id: "7", rdvsp_user_id: 99)
    end

    # The page's button, then RDV-SP's authorization screen
    def authorize
      request = response.parsed_body.at("input[name=request]")["value"]
      post "/pipedrive/autoriser", params: { request: }, headers: browser
      Rack::Utils.parse_query(URI(response.location).query).fetch("state")
    end

    it "has them authorize the bridge once, then opens the plan with their own token" do
      create(:connection, account:, provider_user_id: "501", agent_email: "Lea@Example.fr")
      click
      expect(response.body).to include("Autoriser Pont RDV", "une seule fois")

      state = authorize
      expect(response.location).to start_with("#{rdvsp_url}/oauth/authorize?")
      stub_rdvsp_token(access_token: "agent-access")
      stub_rdvsp_me(id: 78, email: "lea@example.fr")
      get "/rdvsp/callback", params: { code: "abc", state: }, headers: browser
      expect(response).to redirect_to("/pipedrive/prendre-rdv/suite")

      plan = stub_request(:post, "#{rdvsp_url}/api/v1/rdv_plans")
        .with(headers: { "Authorization" => "Bearer agent-access" })
        .to_return_json(status: 201, body: { rdv_plan: { id: 5, url: plan_url } })
      follow_redirect!(headers: browser)

      expect(response).to redirect_to(plan_url)
      expect(plan).to have_been_requested
      expect(account.rdvsp_agent_authorizations.sole).to have_attributes(provider_user_id: "501", agent_id: 78)
      expect(account.rdvsp_authorization.access_token).to eq("import-access")
    end

    it "refuses another RDV-SP agent than the one of their connection" do
      create(:connection, account:, provider_user_id: "501", agent_email: "lea@example.fr")
      click
      state = authorize
      stub_rdvsp_token(refresh_token: "paul-refresh")
      stub_rdvsp_me(id: 79, email: "paul@example.fr")
      revoke = stub_request(:post, "#{rdvsp_url}/oauth/revoke").with(body: hash_including(token: "paul-refresh"))

      get "/rdvsp/callback", params: { code: "abc", state: }, headers: browser

      expect(response).to have_http_status(:forbidden)
      expect(response.body).to include("autre compte", "paul@example.fr")
      expect(revoke).to have_been_requested
      expect(account.rdvsp_agent_authorizations).to be_empty
    end

    it "asks again when their authorization is lost" do
      create(:rdvsp_authorization, account:, provider_user_id: "501", lost_at: 1.day.ago)

      click

      expect(response.body).to include("Autoriser Pont RDV", "ne fonctionne plus")
    end

    it "says to click again when they decline, or come back without a pending plan" do
      click
      get "/rdvsp/callback", params: { error: "access_denied", state: authorize }, headers: browser
      expect(response.body).to include("Vous n’avez pas autorisé", "Prendre RDV")
      expect(account.rdvsp_agent_authorizations).to be_empty

      get "/pipedrive/prendre-rdv/suite", headers: browser
      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("Prendre RDV")
    end

    it "refuses a tampered request" do
      post "/pipedrive/autoriser", params: { request: "abc" }, headers: browser

      expect(response).to have_http_status(:not_found)
    end
  end

  it "ignores a tampered return link" do
    get "/pipedrive/retour/abc", headers: browser

    expect(response).to have_http_status(:not_found)
  end

  it "doesn't exist without its configuration" do
    ENV.delete("PIPEDRIVE_APP_CLIENT_SECRET")

    click

    expect(response).to have_http_status(:not_found)
  end

  describe "installation" do
    it "completes it with the code Pipedrive sends back" do
      exchange = stub_request(:post, "https://oauth.pipedrive.com/oauth/token")
        .with(body: hash_including(code: "abc", redirect_uri: callback_url)).to_return_json(body: {})

      get "/pipedrive/app/callback", headers: browser, params: { code: "abc" }

      expect(exchange).to have_been_requested
      expect(response.body).to include("Prendre RDV", "ri-checkbox-circle-fill")
    end

    it "says so when the user refused, or Pipedrive failed" do
      get "/pipedrive/app/callback", headers: browser, params: { error: "user_denied" }
      expect(response.body).to include("pas été installé", "ri-error-warning-line")

      stub_request(:post, "https://oauth.pipedrive.com/oauth/token").to_return(status: 500)
      get "/pipedrive/app/callback", headers: browser, params: { code: "abc" }
      expect(response).to have_http_status(:bad_gateway)
    end
  end
end
