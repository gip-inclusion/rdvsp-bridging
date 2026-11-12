# Importing a partner's Pipedrive beneficiaries as usagers of an RDV-SP organisation, with a preview
class Admin::UsagerImportsController < Admin::BaseController
  before_action do
    @account = Account.find(params.expect(:account_id))
    @authorization = @account.rdvsp_authorization
    redirect_to admin_account_path(@account), alert: "Aucun agent n’a autorisé la passerelle." unless @authorization
  end

  def new
    @organisations = Rdvsp::Client.new(@authorization).organisations
    @options = Pipedrive::Beneficiaries.options(Pipedrive::Client.new(@account.api_token))
    @active_since = params[:active_since].present? ? parse_date : Date.current.prev_year.beginning_of_year
    @plan = UsagerImports::Plan.call(account: @account, **settings) if params[:organisation_id].present?
  rescue Rdvsp::AuthenticationError
    redirect_to admin_account_path(@account), alert: "L’autorisation RDV-SP est perdue : envoyez un nouveau lien."
  rescue Rdvsp::Error, Pipedrive::Error => e
    redirect_to admin_account_path(@account), alert: "Aperçu impossible : #{e.message}"
  end

  def create
    settings => { organisation_id:, field_key:, option_id:, active_since: }
    usager_import = @account.usager_imports.create!(rdvsp_organisation_id: organisation_id, field_key:, option_id:,
                                                    active_since:)
    ImportUsagersJob.perform_later(usager_import)
    redirect_to admin_account_path(@account), notice: "Import lancé : son bilan s’affiche ci-dessous."
  end

  private

  def settings
    field_key, option_id = params.expect(:field).split(":", 2)
    raise ActionController::BadRequest, "unreadable field" if option_id.blank?

    { organisation_id: Integer(params.expect(:organisation_id)), field_key:, option_id:, active_since: parse_date }
  end

  def parse_date
    Date.iso8601(params.expect(:active_since))
  rescue Date::Error
    raise ActionController::BadRequest, "unreadable date"
  end
end
