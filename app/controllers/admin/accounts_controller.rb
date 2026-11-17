class Admin::AccountsController < Admin::BaseController
  open_to_partners only: %i[index show update]

  def index
    return redirect_to admin_account_path(partner_link.account) if partner_link

    @accounts = Account.includes(:connections).order(:name)
  end

  def show
    @account = accounts.find(params.expect(:id))
  end

  def new; end

  def create
    result = Pipedrive::Onboard.call(api_token: params[:api_token], alert_email: params[:alert_email])
    if result.success?
      redirect_to admin_account_path(result.account), notice: "Compte « #{result.account.name} » prêt."
    else
      flash.now[:alert] = result.errors.to_sentence
      render :new, status: :unprocessable_content
    end
  end

  def update
    account = accounts.find(params.expect(:id))
    account.update!(params.expect(account: %i[alert_email usager_details link_persons]))
    redirect_to admin_account_path(account), notice: "Options enregistrées."
  end
end
