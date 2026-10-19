module Pipedrive
  class Client
    BASE_URL = "https://api.pipedrive.com".freeze
    PAGE_SIZE = 500

    def initialize(api_token)
      @api_token = api_token
    end

    def me = get("/v1/users/me")

    def users = get("/v1/users")

    def activity_types = get("/v1/activityTypes")

    def create_activity_type(name:, icon_key:) = post("/v1/activityTypes", { name:, icon_key: })

    # Yields every activity matching the filters, following cursors
    def each_activity(**filters, &)
      cursor = nil
      loop do
        body = request(:get, "/api/v2/activities", params: { limit: PAGE_SIZE, cursor:, **filters }.compact)
        body["data"].each(&)
        cursor = body.dig("additional_data", "next_cursor")
        break if cursor.nil?
      end
    end

    def activity(id) = get("/api/v2/activities/#{Integer(id)}")

    def create_activity(attributes) = post("/api/v2/activities", attributes)

    def update_activity(id, attributes) = request(:patch, "/api/v2/activities/#{Integer(id)}", body: attributes)["data"]

    def delete_activity(id) = request(:delete, "/api/v2/activities/#{Integer(id)}")["data"]

    def search_persons(term) = get("/api/v2/persons/search", term:, exact_match: true, limit: 2).fetch("items", [])

    def create_person(attributes) = post("/api/v2/persons", attributes)

    def webhooks = get("/v1/webhooks")

    def create_webhook(attributes) = post("/v1/webhooks", attributes)

    def delete_webhook(id) = request(:delete, "/v1/webhooks/#{Integer(id)}")

    private

    def get(path, **params) = request(:get, path, params:)["data"]

    def post(path, body) = request(:post, path, body:)["data"]

    def request(verb, path, params: {}, body: nil)
      response = connection.run_request(verb, path, body&.to_json, nil) { |req| req.params.update(params) }
      handle(response)
    rescue Faraday::Error => e
      raise Error, "#{e.class}: #{e.message}"
    end

    def handle(response)
      case response.status
      when 200..299 then response.body
      when 401, 403 then raise AuthenticationError, "Pipedrive refused the API token (#{response.status})"
      when 404 then raise NotFoundError, "not found (404)"
      else raise Error, "Pipedrive error #{response.status}: #{response.body.try(:[], 'error')}"
      end
    end

    def connection
      headers = { "x-api-token" => @api_token, "Content-Type" => "application/json" }
      @connection ||= Faraday.new(BASE_URL, headers:, request: { timeout: 10, open_timeout: 5 }) do |f|
        f.request :retry, max: 3, interval: 1, backoff_factor: 2, retry_statuses: [429, 502, 503, 504],
                          methods: %i[get delete patch]
        f.response :json, content_type: /\bjson$/
      end
    end
  end
end
