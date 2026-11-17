require "rails_helper"

RSpec.describe "Partner links: one account's admin without the password" do
  let(:browser) { { "User-Agent" => "Mozilla/5.0 (Macintosh) AppleWebKit/605.1.15 Version/18.0 Safari/605.1.15" } }
  let(:team) do
    browser.merge("Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", "admin"))
  end
  let(:account) { create(:account, name: "Massajobs") }
  let(:link) { create(:partner_link, account:) }
  let(:token) { link.generate_token_for(:partner_access) }

  def open_link
    post "/equipe/#{token}", headers: browser
  end

  describe "opening a link" do
    it "shows a landing page that doesn't count, then counts the click and opens the account" do
      get "/equipe/#{token}", headers: browser

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Massajobs", "Continuer")
      expect(link.reload.uses_count).to eq(0)

      open_link

      expect(response).to redirect_to("/admin/accounts/#{account.id}")
      expect(link.reload).to have_attributes(uses_count: 1, last_used_at: be_present)
    end

    it "says an unknown or revoked link no longer works" do
      get "/equipe/nope", headers: browser
      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("plus valable")

      link.revoke!
      post "/equipe/#{token}", headers: browser
      expect(response).to have_http_status(:not_found)
      expect(link.reload.uses_count).to eq(0)
    end
  end

  describe "a partner's session" do
    let(:connection) { create(:connection, account:) }
    let(:other) { create(:account) }
    let(:other_connection) { create(:connection, account: other) }

    before { open_link }

    it "reaches their account's pages without the password" do
      get "/admin/accounts/#{account.id}", headers: browser
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Massajobs")

      patch "/admin/accounts/#{account.id}", params: { account: { link_persons: "1" } }, headers: browser
      expect(account.reload.link_persons).to be(true)

      get "/admin/connections/#{connection.id}", headers: browser
      expect(response).to have_http_status(:ok)
    end

    it "reaches no other account, nor the team's pages" do
      ["/admin/accounts/#{other.id}", "/admin/connections/#{other_connection.id}",
       "/admin/accounts/#{other.id}/connections/new", "/admin/accounts/#{other.id}/rdv_activity_type/edit",
       "/admin/accounts/new", "/admin/google/connect",
       "/admin/connections/#{connection.id}/ignored_rdvs/new",].each do |path|
        get path, headers: browser
        expect(response).to have_http_status(:not_found), path
      end

      patch "/admin/accounts/#{other.id}", params: { account: { link_persons: "1" } }, headers: browser
      expect(response).to have_http_status(:not_found)
      expect(other.reload.link_persons).to be(false)
    end

    it "can't use the team's troubleshooting actions" do
      rdv = create(:rdv, connection:, ignored_at: Time.current)

      post "/admin/connections/#{connection.id}/rebuild", headers: browser
      expect(response).to have_http_status(:not_found)

      post "/admin/rdvs/#{rdv.id}/release", headers: browser
      expect(response).to have_http_status(:not_found)
      expect(rdv.reload.ignored_at).to be_present
    end

    it "goes to their account from the accounts list" do
      get "/admin", headers: browser

      expect(response).to redirect_to("/admin/accounts/#{account.id}")
    end

    it "sees neither the team's navigation nor its troubleshooting actions" do
      create(:rdv, connection:, ignored_at: Time.current)

      get "/admin/accounts/#{account.id}", headers: browser
      expect(response.body).to include("Quitter").and not_include(">Comptes<")

      get "/admin/connections/#{connection.id}", headers: browser
      expect(response.body).to include("Massajobs", "Identifiants CalDAV")
        .and not_include("Reconstruire", "Ignorer les RDV reçus avant", "Transmettre quand même")
    end

    it "ends when the link is revoked" do
      link.revoke!

      get "/admin/accounts/#{account.id}", headers: browser
      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("plus valable")

      get "/admin/accounts/#{account.id}", headers: browser
      expect(response).to have_http_status(:unauthorized)
    end

    it "ends when they leave" do
      delete "/equipe", headers: browser
      expect(response.body).to include("quitté")

      get "/admin/accounts/#{account.id}", headers: browser
      expect(response).to have_http_status(:unauthorized)
    end
  end

  it "leaves the team's password as it was without a partner session" do
    get "/admin/accounts/#{account.id}", headers: browser
    expect(response).to have_http_status(:unauthorized)

    get "/admin/accounts/#{account.id}", headers: team
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(">Comptes<").and not_include("Quitter")

    connection = create(:connection, account:)
    create(:rdv, connection:, ignored_at: Time.current)
    get "/admin/connections/#{connection.id}", headers: team
    expect(response.body).to include("Reconstruire", "Ignorer les RDV reçus avant", "Transmettre quand même")
  end
end
