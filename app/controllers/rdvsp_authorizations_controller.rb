# An agent authorizes the bridge to call RDV-SP's API in their name: for the account, from a link staff sent them, or
# for themselves, from the "Prendre RDV" button (PipedriveAppController)
class RdvspAuthorizationsController < ApplicationController
  include PublicMessages
  include RdvspOauth

  layout "public"

  before_action { not_found unless Rdvsp::Oauth.configured? }
  before_action :set_account, only: %i[show create]

  def show; end

  def create = start_rdvsp_oauth("account_id" => @account.id)

  def callback
    pending = session.delete(:rdvsp_oauth) || {}
    retry_hint = retry_hint(pending)
    unless expected_state?(pending["state"])
      return message("Cette demande a expiré", "#{retry_hint} pour recommencer.", :bad_request)
    end
    if params[:error].present?
      return message("Vous n’avez pas autorisé Pont RDV", "Rien n’a été modifié. #{retry_hint} si vous changez d’avis.")
    end

    authorize(pending)
  rescue Rdvsp::Error => e
    Rails.logger.warn("RDV-SP authorization failed: #{e.message}")
    message("RDV Service Public n’a pas répondu comme prévu", "#{retry_hint} pour réessayer.", :bad_gateway)
  end

  private

  def set_account
    @account = RdvspAuthorization.account_for(params[:token])
    return if @account

    message("Ce lien n’est plus valable", "Demandez un nouveau lien à l’équipe qui vous l’a envoyé.", :not_found)
  end

  # From the button, the agent goes on to the RDV plan they asked for
  def authorize(pending)
    provider_user_id = pending["provider_user_id"]
    RdvspAuthorization.authorize!(account: Account.find(pending["account_id"]), provider_user_id:,
                                  code: params[:code].to_s, redirect_uri: rdvsp_redirect_uri)
    if provider_user_id
      session[:pipedrive_rdv_plan] = pending.slice("account_id", "provider_user_id", "person_id")
      return redirect_to(pipedrive_rdv_plan_resume_path)
    end

    message("C’est fait", "Pont RDV peut maintenant créer des usagers dans RDV Service Public en votre nom. " \
                          "Vous pouvez fermer cette page.", success: true)
  end

  def retry_hint(pending)
    return "Cliquez à nouveau sur « Prendre RDV » dans Pipedrive" if pending["provider_user_id"]

    "Rouvrez le lien qui vous a été envoyé"
  end

  def expected_state?(state) = state.present? && ActiveSupport::SecurityUtils.secure_compare(state, params[:state].to_s)

  def not_found = head(:not_found)
end
