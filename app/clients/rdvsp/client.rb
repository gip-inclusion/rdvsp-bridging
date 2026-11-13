module Rdvsp
  # RDV-SP's API v1, as the agent who authorized the bridge
  class Client
    def initialize(authorization)
      @authorization = authorization
    end

    def me = request(:get, "/api/v1/agents/me").fetch("agent")

    def organisations = enum_for(:each_page, "/api/v1/organisations", "organisations").to_a

    def each_organisation_user(organisation_id, &)
      each_page("/api/v1/organisations/#{Integer(organisation_id)}/users", "users", &)
    end

    def create_user(attributes) = request(:post, "/api/v1/users", body: attributes).fetch("user")

    def create_rdv_plan(attributes) = request(:post, "/api/v1/rdv_plans", body: attributes).fetch("rdv_plan")

    private

    def each_page(path, root, &)
      page = 1
      while page
        body = request(:get, path, params: { page: })
        body.fetch(root).each(&)
        page = body.dig("meta", "next_page")
      end
    end

    def request(verb, path, params: {}, body: nil, refreshed: false)
      response = connection.run_request(verb, path, body&.to_json, authorization_header) { it.params.update(params) }
      return handle(response) unless response.status == 401
      raise AuthenticationError, "RDV-SP refused the access token (401)" if refreshed

      @authorization.refresh!
      request(verb, path, params:, body:, refreshed: true)
    rescue Faraday::Error => e
      raise Error, "#{e.class}: #{e.message}"
    end

    def handle(response)
      case response.status
      when 200..299 then response.body
      when 422 then raise UnprocessableError, response.body.try(:[], "errors")
      else raise Error, "RDV-SP error #{response.status}"
      end
    end

    def authorization_header = { "Authorization" => "Bearer #{@authorization.fresh_access_token}" }

    # A usager created twice is refused by its external reference, so retrying a POST is safe
    def connection
      @connection ||= Faraday.new(Oauth.url, headers: { "Content-Type" => "application/json" },
                                             request: { timeout: 15, open_timeout: 5 }) do |f|
        f.request :retry, max: 3, interval: 1, backoff_factor: 2, retry_statuses: [429, 502, 503, 504],
                          methods: %i[get post]
        f.response :json, content_type: /\bjson$/
      end
    end
  end
end
