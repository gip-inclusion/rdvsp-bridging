# A partner's agent authorizes the bridge to call RDV-SP's API in their name, from a link staff sent them
class RdvspAuthorizationsController < ApplicationController
  layout "public"

  before_action { not_found unless Rdvsp::Oauth.configured? }
  before_action :set_account, only: %i[show create]

  def show; end

  def create
    state = SecureRandom.urlsafe_base64(24)
    session[:rdvsp_oauth] = { "state" => state, "account_id" => @account.id }
    redirect_to Rdvsp::Oauth.authorize_url(redirect_uri:, state:), allow_other_host: true
  end

  def callback
    pending = session.delete(:rdvsp_oauth) || {}
    unless expected_state?(pending["state"])
      return message("Cette demande a expiré", "Rouvrez le lien qui vous a été envoyé pour recommencer.", :bad_request)
    end
    if params[:error].present?
      return message("Vous n’avez pas autorisé Pont RDV",
                     "Rien n’a été modifié. Rouvrez le lien qui vous a été envoyé si vous changez d’avis.")
    end

    RdvspAuthorization.authorize!(account: Account.find(pending["account_id"]), code: params[:code].to_s, redirect_uri:)
    message("C’est fait", "Pont RDV peut maintenant créer des usagers dans RDV Service Public en votre nom. " \
                          "Vous pouvez fermer cette page.")
  rescue Rdvsp::Error => e
    Rails.logger.warn("RDV-SP authorization failed: #{e.message}")
    message("RDV Service Public n’a pas répondu comme prévu", "Rouvrez le lien qui vous a été envoyé pour réessayer.",
            :bad_gateway)
  end

  private

  def set_account
    @account = RdvspAuthorization.account_for(params[:token])
    return if @account

    message("Ce lien n’est plus valable", "Demandez un nouveau lien à l’équipe qui vous l’a envoyé.", :not_found)
  end

  def expected_state?(state) = state.present? && ActiveSupport::SecurityUtils.secure_compare(state, params[:state].to_s)

  def message(title, text, status = :ok) = render(:message, locals: { title:, text: }, status:)

  def not_found = head(:not_found)

  def redirect_uri = "#{Rails.configuration.x.base_url}#{rdvsp_callback_path}"
end
