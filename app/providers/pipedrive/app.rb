module Pipedrive
  # The bridge's private app in Pipedrive: its link actions send JWT-signed clicks, its installation goes through OAuth
  module App
    class InvalidToken < StandardError; end

    OAUTH_URL = "https://oauth.pipedrive.com".freeze

    module_function

    def configured? = [client_id, client_secret].all?(&:present?)

    # => { "userId" => …, "companyId" => …, … }, signed with the client secret (the action's "JWT secret" left empty)
    def claims(token)
      JWT.decode(token.to_s, client_secret, true, algorithm: "HS256").first
    rescue JWT::DecodeError => e
      raise InvalidToken, e.message
    end

    # The bridge keeps using the account's API token: the tokens are only fetched to complete the installation
    def complete_installation(code:, redirect_uri:)
      response = oauth.post("/oauth/token", { grant_type: "authorization_code", code:, redirect_uri: })
      raise Error, "Pipedrive OAuth error #{response.status}" unless response.success?
    rescue Faraday::Error => e
      raise Error, "#{e.class}: #{e.message}"
    end

    def oauth
      Faraday.new(OAUTH_URL, request: { timeout: 15, open_timeout: 5 }) do |f|
        f.request :url_encoded
        f.request :authorization, :basic, client_id, client_secret
      end
    end

    def client_id = ENV["PIPEDRIVE_APP_CLIENT_ID"]

    def client_secret = ENV["PIPEDRIVE_APP_CLIENT_SECRET"]
  end
end
