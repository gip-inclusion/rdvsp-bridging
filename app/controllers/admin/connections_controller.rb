class Admin::ConnectionsController < Admin::BaseController
  def show
    @connection = Connection.find(params.expect(:id))
    @password = flash[:password]
  end

  def new
    @account = Account.find(params.expect(:account_id))
    @users = Pipedrive::Client.new(@account.api_token).users.select { it["active_flag"] }
  end

  def create
    account = Account.find(params.expect(:account_id))
    result = Connections::Create.call(account:, provider_user_id: params[:provider_user_id],
                                      agent_email: params[:agent_email])
    if result.success?
      redirect_to admin_connection_path(result.connection), flash: { password: result.password }
    else
      redirect_to new_admin_account_connection_path(account), alert: result.errors.to_sentence
    end
  end

  def update
    connection = Connection.find(params.expect(:id))
    connection.update!(params.expect(connection: %i[agent_email include_all_day]))
    RebuildConnectionJob.perform_later(connection)
    redirect_to admin_connection_path(connection), notice: "Options enregistrées."
  end

  def reset_password
    connection = Connection.find(params.expect(:id))
    password = Connection.generate_password
    connection.update!(password:)
    redirect_to admin_connection_path(connection), flash: { password: }
  end

  def rebuild
    connection = Connection.find(params.expect(:id))
    RebuildConnectionJob.perform_later(connection)
    redirect_to admin_connection_path(connection), notice: "Reconstruction lancée."
  end
end
