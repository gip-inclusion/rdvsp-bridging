class Admin::RdvspAuthorizationsController < Admin::BaseController
  def destroy
    account = Account.find(params.expect(:account_id))
    account.rdvsp_authorization&.withdraw!
    redirect_to admin_account_path(account), notice: "Autorisation RDV-SP retirée."
  end
end
