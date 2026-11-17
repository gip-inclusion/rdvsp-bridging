# An agent's own authorization, given at their first "Prendre RDV" click
class Admin::RdvspAgentAuthorizationsController < Admin::BaseController
  open_to_partners

  def destroy
    account = accounts.find(params.expect(:account_id))
    account.rdvsp_agent_authorizations.find(params.expect(:id)).withdraw!
    redirect_to admin_account_path(account), notice: "Autorisation de l’agent retirée."
  end
end
