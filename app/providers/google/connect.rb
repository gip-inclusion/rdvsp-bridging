module Google
  # Finishes the OAuth flow: stores the Google user's grant as an account and connects their primary calendar
  class Connect < BaseService
    def initialize(code:, redirect_uri:, agent_email: nil)
      @code = code
      @redirect_uri = redirect_uri
      @agent_email = agent_email
    end

    def call
      grant = Oauth.exchange_code(code: @code, redirect_uri: @redirect_uri)
      fail!("Google did not return a refresh token") if grant[:refresh_token].blank?

      account = Account.find_or_initialize_by(provider: "google", provider_company_id: grant[:sub])
      account.update!(name: grant[:email], api_token: grant[:refresh_token], access_token: grant[:access_token],
                      access_token_expires_at: grant[:expires_at], failing_since: nil, last_error: nil)
      result.account = account
      result.connection = account.connections.find_by(provider_user_id: "primary") || create_connection(account, grant)
    rescue Google::Error => e
      fail!(e.message)
    end

    private

    def create_connection(account, grant)
      created = call_service!(Connections::Create, account:, provider_user_id: "primary",
                                                   provider_user_name: grant[:email],
                                                   agent_email: @agent_email || grant[:email])
      result.password = created.password
      created.connection
    end
  end
end
