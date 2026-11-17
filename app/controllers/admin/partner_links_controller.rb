# The links the team sends a partner's admin to manage their account (docs/partner-links.md): the team's only
class Admin::PartnerLinksController < Admin::BaseController
  before_action { @account = accounts.find(params.expect(:account_id)) }

  def create
    link = @account.partner_links.create(label: params[:label].to_s.strip)
    if link.persisted?
      redirect_to admin_account_path(@account), notice: "Lien créé : copiez-le pour l’envoyer au partenaire."
    else
      redirect_to admin_account_path(@account), alert: "Indiquez pour qui est le lien."
    end
  end

  def destroy
    @account.partner_links.find(params.expect(:id)).revoke!
    redirect_to admin_account_path(@account), notice: "Lien révoqué."
  end
end
