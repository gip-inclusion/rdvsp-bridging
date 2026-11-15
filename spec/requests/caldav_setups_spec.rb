require "rails_helper"

RSpec.describe "CalDAV credentials for an agent, from a link the team sent" do
  let(:connection) { create(:connection).tap(&:start_caldav_link!) }
  let(:token) { connection.generate_token_for(:caldav_setup) }
  let(:browser) { { "User-Agent" => "Mozilla/5.0 (Macintosh) AppleWebKit/605.1.15 Version/18.0 Safari/605.1.15" } }

  it "gives the URL and username, and creates a password only on request" do
    get "/agenda/#{token}", headers: browser

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(connection.username, "http://localhost:3010#{connection.calendar_path}",
                                     "Générer mon mot de passe")
    expect(connection.reload.password_matches?("caldav-password")).to be(true)
  end

  it "shows the new password under the instructions once, then offers another for 15 minutes" do
    allow(Connection).to receive(:generate_password).and_return("nouveau-mot-de-passe")

    post "/agenda/#{token}", headers: browser
    expect(response).to redirect_to("/agenda/#{token}")
    follow_redirect!(headers: browser)
    expect(response.body).to include("Synchronisation d’agenda", "nouveau-mot-de-passe")
    expect(response.headers["Cache-Control"]).to include("no-store")
    expect(connection.reload.password_matches?("nouveau-mot-de-passe")).to be(true)

    travel 14.minutes
    get "/agenda/#{token}", headers: browser
    expect(response.body).to include("Générer un nouveau mot de passe").and not_include("nouveau-mot-de-passe")

    travel 2.minutes
    get "/agenda/#{token}", headers: browser
    expect(response).to have_http_status(:not_found)
    expect(response.body).to include("Ce lien n’est plus valable")
  end

  it "stops working after 7 days, or once the team creates another link" do
    token
    travel 8.days
    get "/agenda/#{token}", headers: browser
    expect(response).to have_http_status(:not_found)

    travel_back
    old = connection.generate_token_for(:caldav_setup)
    connection.start_caldav_link!
    get "/agenda/#{old}", headers: browser
    expect(response).to have_http_status(:not_found)
  end
end
