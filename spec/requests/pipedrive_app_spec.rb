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
    before { create(:rdvsp_authorization, account:) }

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
      click

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("dans quelle organisation")
    end

    it "trusts the company of the signed token, not the one in the URL" do
      create(:account, provider_company_id: "24680")

      click(token: pipedrive_click_token(company_id: 24_680), companyId: 13_579)

      expect(response.body).to include("n’a pas accès à RDV Service Public")
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

    it "says so when RDV-SP fails" do
      create(:imported_usager, account:, provider_person_id: "7", rdvsp_user_id: 99)
      stub_request(:post, "#{rdvsp_url}/api/v1/rdv_plans").to_return(status: 500)

      click

      expect(response).to have_http_status(:bad_gateway)
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
      expect(response.body).to include("Prendre RDV")
    end

    it "says so when the user refused, or Pipedrive failed" do
      get "/pipedrive/app/callback", headers: browser, params: { error: "user_denied" }
      expect(response.body).to include("pas été installé")

      stub_request(:post, "https://oauth.pipedrive.com/oauth/token").to_return(status: 500)
      get "/pipedrive/app/callback", headers: browser, params: { code: "abc" }
      expect(response).to have_http_status(:bad_gateway)
    end
  end
end
