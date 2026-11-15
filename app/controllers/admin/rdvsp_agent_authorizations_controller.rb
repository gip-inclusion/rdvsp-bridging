# An agent's own authorization, given at their first "Prendre RDV" click
class Admin::RdvspAgentAuthorizationsController < Admin::BaseController
  def destroy
    account = Account.find(params.expect(:account_id))
    authorization = account.rdvsp_agent_authorizations.find(params.expect(:id))
    authorization.revoke
    authorization.destroy!
    redirect_to admin_account_path(account), notice: "Autorisation de l’agent retirée."
  end
end
