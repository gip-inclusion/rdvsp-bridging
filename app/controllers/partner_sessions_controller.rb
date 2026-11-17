# A partner's admin opens their account's admin pages from a link the team sent (docs/partner-links.md). The landing
# page only shows where the link leads, so a link preview neither counts nor opens anything: "Continuer" does.
class PartnerSessionsController < ApplicationController
  include PublicMessages

  layout "public"

  before_action only: %i[show create] do
    @partner_link = PartnerLink.from_token(params[:token])
    message("Ce lien n’est plus valable", "Demandez un nouveau lien à l’équipe de Pont RDV.", :not_found) \
      unless @partner_link
  end

  def show; end

  def create
    @partner_link.record_use!
    reset_session
    session[:partner_link_id] = @partner_link.id
    Rails.logger.info("Partner link #{@partner_link.id} opened account #{@partner_link.account_id}")
    redirect_to admin_account_path(@partner_link.account)
  end

  def destroy
    reset_session
    message("Vous avez quitté Pont RDV", "Pour revenir, rouvrez le lien que l’équipe vous a envoyé.", success: true)
  end
end
