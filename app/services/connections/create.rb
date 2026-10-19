# Connects a provider user to an RDV-SP agent and issues the CalDAV credentials the agent pastes into RDV-SP
module Connections
  class Create < BaseService
    def initialize(account:, provider_user_id:, agent_email: nil, provider_user_name: nil)
      @account = account
      @provider_user_id = provider_user_id.to_s
      @agent_email = agent_email
      @provider_user_name = provider_user_name
    end

    def call
      password = Connection.generate_password
      connection = @account.connections.new(provider_user_id: @provider_user_id, agent_email: @agent_email,
                                            provider_user_name: @provider_user_name || provider_user_name, password:)
      save_record!(connection)
      RebuildConnectionJob.perform_later(connection)
      result.connection = connection
      result.password = password
    end

    private

    def provider_user_name
      Pipedrive::Client.new(@account.api_token).users.find { it["id"].to_s == @provider_user_id }&.dig("name")
    rescue Pipedrive::Error
      nil
    end
  end
end
