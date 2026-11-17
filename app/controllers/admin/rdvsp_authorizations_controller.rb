class Admin::RdvspAuthorizationsController < Admin::BaseController
  open_to_partners

  def destroy
    account = accounts.find(params.expect(:account_id))
    account.rdvsp_authorization&.withdraw!
    redirect_to admin_account_path(account), notice: "Autorisation RDV-SP retirée."
  end
end
