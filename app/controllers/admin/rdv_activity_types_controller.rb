# The Pipedrive activity type of the RDVs the bridge writes: its own by default, or one the partner already uses
class Admin::RdvActivityTypesController < Admin::BaseController
  before_action do
    @account = Account.find(params.expect(:account_id))
    head :not_found unless @account.provider == "pipedrive"
  end

  def edit
    @types = client.activity_types.select { it["active_flag"] }
  rescue Pipedrive::Error => e
    redirect_to admin_account_path(@account), alert: "Types d’activité indisponibles : #{e.message}"
  end

  def update
    name = params[:name].to_s.strip
    key = name.present? ? client.create_activity_type(name:, icon_key: "calendar")["key_string"] : params.expect(:key)
    @account.update!(rdv_activity_type_key: key)
    redirect_to admin_account_path(@account), notice: "Type d’activité enregistré."
  rescue Pipedrive::Error => e
    redirect_to admin_account_path(@account), alert: "Pipedrive a refusé le type d’activité : #{e.message}"
  end

  private

  def client = Pipedrive::Client.new(@account.api_token)
end
