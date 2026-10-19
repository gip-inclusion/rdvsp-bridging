module Google
  # OAuth 2.0 web flow for one Google user's calendar (scope limited to events + identity)
  module Oauth
    AUTHORIZE_URL = "https://accounts.google.com/o/oauth2/v2/auth".freeze
    TOKEN_URL = "https://oauth2.googleapis.com/token".freeze
    SCOPES = %w[openid email https://www.googleapis.com/auth/calendar.events].freeze

    module_function

    def configured? = client_id.present? && client_secret.present?

    def authorize_url(redirect_uri:, state:)
      query = { client_id:, redirect_uri:, state:, response_type: "code", scope: SCOPES.join(" "),
                access_type: "offline", prompt: "consent", include_granted_scopes: "true", }
      "#{AUTHORIZE_URL}?#{query.to_query}"
    end

    # => { refresh_token:, access_token:, expires_at:, email:, sub: }
    def exchange_code(code:, redirect_uri:)
      body = token_request(code:, redirect_uri:, grant_type: "authorization_code")
      identity = decode_id_token(body["id_token"])
      { refresh_token: body["refresh_token"], access_token: body["access_token"],
        expires_at: body["expires_in"].to_i.seconds.from_now, email: identity["email"], sub: identity["sub"], }
    end

    def refresh(refresh_token)
      body = token_request(refresh_token:, grant_type: "refresh_token")
      { access_token: body["access_token"], expires_at: body["expires_in"].to_i.seconds.from_now }
    end

    def token_request(**params)
      response = Faraday.post(TOKEN_URL, params.merge(client_id:, client_secret:))
      body = JSON.parse(response.body)
      raise AuthenticationError, "Google refused the grant: #{body['error']}" if response.status.in?([400, 401])
      raise Error, "Google token error #{response.status}" unless response.success?

      body
    rescue Faraday::Error, JSON::ParserError => e
      raise Error, "#{e.class}: #{e.message}"
    end

    # The token comes straight from Google's token endpoint over TLS: its signature doesn't need checking here
    def decode_id_token(token)
      payload = token.to_s.split(".")[1].to_s.delete("=")
      JSON.parse(Base64.urlsafe_decode64(payload + ("=" * ((4 - (payload.length % 4)) % 4))))
    end

    def client_id = ENV["GOOGLE_CLIENT_ID"]

    def client_secret = ENV["GOOGLE_CLIENT_SECRET"]
  end
end
