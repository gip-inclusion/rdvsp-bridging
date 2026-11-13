# The RDV-SP organisation where the "Prendre RDV" button creates the persons not transferred yet
class Admin::RdvspOrganisationsController < Admin::BaseController
  before_action do
    @account = Account.find(params.expect(:account_id))
    redirect_to admin_account_path(@account), alert: "Aucun agent n’a autorisé la passerelle." unless authorization
  end

  def edit
    @organisations = Rdvsp::Client.new(authorization).organisations
  rescue Rdvsp::AuthenticationError
    redirect_to admin_account_path(@account), alert: "L’autorisation RDV-SP est perdue : envoyez un nouveau lien."
  rescue Rdvsp::Error => e
    redirect_to admin_account_path(@account), alert: "Organisations indisponibles : #{e.message}"
  end

  def update
    @account.update!(rdvsp_organisation_id: Integer(params.expect(:organisation_id)))
    redirect_to admin_account_path(@account), notice: "Organisation enregistrée."
  end

  private

  def authorization = @account.rdvsp_authorization
end
