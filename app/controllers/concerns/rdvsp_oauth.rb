# Sends someone to RDV-SP to authorize the bridge. RDV-SP brings them back to RdvspAuthorizationsController#callback,
# the only redirect URI it knows, with the state kept here along what the callback needs.
module RdvspOauth
  private

  def start_rdvsp_oauth(pending)
    state = SecureRandom.urlsafe_base64(24)
    session[:rdvsp_oauth] = pending.merge("state" => state)
    redirect_to Rdvsp::Oauth.authorize_url(redirect_uri: rdvsp_redirect_uri, state:), allow_other_host: true
  end

  def rdvsp_redirect_uri = "#{Rails.configuration.x.base_url}#{rdvsp_callback_path}"
end
