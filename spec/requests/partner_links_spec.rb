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
end
