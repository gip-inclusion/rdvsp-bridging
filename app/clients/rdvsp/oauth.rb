module Rdvsp
  # OAuth 2.0 authorization code flow against RDV-SP's Doorkeeper (one `write` scope, 2-hour tokens, refresh tokens)
  module Oauth
    module_function

    def configured? = [url, client_id, client_secret].all?(&:present?)

    def authorize_url(redirect_uri:, state:)
      "#{url}/oauth/authorize?#{{ client_id:, redirect_uri:, response_type: 'code', state: }.to_query}"
    end

    # => { access_token:, refresh_token:, expires_at: }
    def exchange_code(code:, redirect_uri:) = tokens(grant_type: "authorization_code", code:, redirect_uri:)

    def refresh(refresh_token) = tokens(grant_type: "refresh_token", refresh_token:)

    def revoke(token) = post("/oauth/revoke", token:)

    def tokens(**params)
      body = post("/oauth/token", **params)
      { access_token: body.fetch("access_token"), refresh_token: body.fetch("refresh_token"),
        expires_at: body.fetch("expires_in").to_i.seconds.from_now, }
    end

    def post(path, **params)
      response = Faraday.post("#{url}#{path}", params.merge(client_id:, client_secret:))
      if response.status.in?([400, 401])
        raise AuthenticationError, "RDV-SP refused the grant: #{error_code(response.body)}"
      end
      raise Error, "RDV-SP OAuth error #{response.status}" unless response.success?

      JSON.parse(response.body.presence || "{}")
    rescue Faraday::Error, JSON::ParserError => e
      raise Error, "#{e.class}: #{e.message}"
    end

    def error_code(body)
      JSON.parse(body)["error"]
    rescue JSON::ParserError, TypeError
      nil
    end

    def url = ENV["RDVSP_URL"]&.delete_suffix("/")

    def client_id = ENV["RDVSP_OAUTH_CLIENT_ID"]

    def client_secret = ENV["RDVSP_OAUTH_CLIENT_SECRET"]
  end
end
