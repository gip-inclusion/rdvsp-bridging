# An agent authorizes the bridge to call RDV-SP's API in their name: for the account, from a link staff sent them, or
# for themselves, from the "Prendre RDV" button (PipedriveAppController)
class RdvspAuthorizationsController < ApplicationController
  include PublicMessages
  include RdvspOauth

  layout "public"

  before_action { not_found unless Rdvsp::Oauth.configured? }
  before_action :set_account, only: %i[show create]

  def show; end

  def create = start_rdvsp_oauth("flow" => "account", "account_id" => @account.id)

  def callback
    @pending = session.delete(:rdvsp_oauth) || {}
    unless expected_state?(@pending["state"])
      return message("Cette demande a expiré", "#{start_over.upcase_first} pour recommencer.", :bad_request)
    end
    if params[:error].present?
      return message("Vous n’avez pas autorisé Pont RDV", "Rien n’a été modifié. #{start_over.upcase_first} si vous " \
                                                          "changez d’avis.")
    end

    authorize
  rescue RdvspAuthorization::OtherAgent => e
    message("Vous êtes connecté à RDV Service Public avec un autre compte",
            "RDV Service Public vous a connecté en tant que #{e.agent_email || 'un autre agent'}, qui n’est pas " \
            "l’agent de votre compte Pipedrive. Déconnectez-vous de RDV Service Public, puis #{start_over}.",
            :forbidden)
  rescue Rdvsp::Error => e
    Rails.logger.warn("RDV-SP authorization failed: #{e.message}")
    message("RDV Service Public n’a pas répondu comme prévu", "#{start_over.upcase_first} pour réessayer.",
            :bad_gateway)
  end

  private

  def set_account
    @account = RdvspAuthorization.account_for(params[:token])
    return if @account

    message("Ce lien n’est plus valable", "Demandez un nouveau lien à l’équipe qui vous l’a envoyé.", :not_found)
  end

  # From the button, the agent goes on to the RDV plan they asked for
  def authorize
    account = Account.find(@pending["account_id"])
    if button?
      RdvspAuthorization.authorize!(account:, provider_user_id: @pending.fetch("provider_user_id"),
                                    code: params[:code].to_s, redirect_uri: rdvsp_redirect_uri)
      session[:pipedrive_rdv_plan] = @pending.slice("account_id", "provider_user_id", "person_id")
      return redirect_to(pipedrive_rdv_plan_resume_path)
    end

    RdvspAuthorization.authorize!(account:, code: params[:code].to_s, redirect_uri: rdvsp_redirect_uri)
    message("C’est fait", "Pont RDV peut maintenant créer des usagers dans RDV Service Public en votre nom. " \
                          "Vous pouvez fermer cette page.", success: true)
  end

  def button? = @pending["flow"] == "button"

  # Sessions from before the button have no flow: they come from the account's link
  def start_over
    if button? then "cliquez à nouveau sur « Prendre RDV » dans Pipedrive"
    elsif @pending["account_id"] then "rouvrez le lien qui vous a été envoyé"
    else "recommencez depuis le lien ou le bouton qui vous a amené ici"
    end
  end

  def expected_state?(state) = state.present? && ActiveSupport::SecurityUtils.secure_compare(state, params[:state].to_s)

  def not_found = head(:not_found)
end
