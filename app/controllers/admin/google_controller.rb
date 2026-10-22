class Admin::GoogleController < Admin::BaseController
  def connect
    return redirect_to admin_root_path, alert: "GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET manquants." unless Google::Oauth.configured?

    session[:google_oauth_state] = SecureRandom.urlsafe_base64(24)
    redirect_to Google::Oauth.authorize_url(redirect_uri:, state: session[:google_oauth_state]), allow_other_host: true
  end

  def callback
    state = session.delete(:google_oauth_state)
    unless state.present? && ActiveSupport::SecurityUtils.secure_compare(state, params[:state].to_s)
      return redirect_to admin_root_path, alert: "Connexion Google expirée, veuillez recommencer."
    end
    return redirect_to admin_root_path, alert: "Connexion Google refusée (#{params[:error]})." if params[:error]

    result = Google::Connect.call(code: params[:code].to_s, redirect_uri:)
    if result.failure?
      redirect_to admin_root_path, alert: result.errors.to_sentence
    elsif result.password
      redirect_to admin_connection_path(result.connection), flash: { password: result.password }
    else
      redirect_to admin_account_path(result.account), notice: "Autorisation Google renouvelée."
    end
  end

  private

  def redirect_uri = "#{Rails.configuration.x.base_url}#{admin_google_callback_path}"
end
