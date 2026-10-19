class Admin::AccountsController < Admin::BaseController
  def index
    @accounts = Account.includes(:connections).order(:name)
  end

  def show
    @account = Account.find(params.expect(:id))
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
    account = Account.find(params.expect(:id))
    account.update!(params.expect(account: %i[alert_email usager_details link_persons]))
    redirect_to admin_account_path(account), notice: "Options enregistrées."
  end
end
