module Google
  # Google Calendar API v3 for one account (one Google user), refreshing its access token when needed
  class Client
    BASE_URL = "https://www.googleapis.com/calendar/v3".freeze
    PAGE_SIZE = 2500

    def initialize(account)
      @account = account
    end

    # Yields every event instance (recurring events expanded) in the window, following pages
    def each_event(calendar_id, time_min:, time_max:, updated_min: nil, &)
      page_token = nil
      loop do
        params = { singleEvents: true, showDeleted: updated_min.present?, maxResults: PAGE_SIZE,
                   pageToken: page_token, timeMin: time_min.utc.iso8601, timeMax: time_max.utc.iso8601,
                   updatedMin: updated_min&.utc&.iso8601, }
        body = request(:get, "calendars/#{escape(calendar_id)}/events", params: params.compact)
        body.fetch("items", []).each(&)
        page_token = body["nextPageToken"]
        break if page_token.nil?
      end
    end

    def insert_event(calendar_id, attributes)
      request(:post, "calendars/#{escape(calendar_id)}/events", body: attributes)
    end

    def patch_event(calendar_id, id, attributes)
      request(:patch, "calendars/#{escape(calendar_id)}/events/#{escape(id)}", body: attributes)
    end

    def delete_event(calendar_id, id) = request(:delete, "calendars/#{escape(calendar_id)}/events/#{escape(id)}")

    private

    def escape(value) = ERB::Util.url_encode(value)

    def request(verb, path, params: {}, body: nil)
      response = connection.run_request(verb, path, body&.to_json, nil) do |req|
        req.params.update(params)
        req.headers["Authorization"] = "Bearer #{access_token}"
      end
      handle(response)
    rescue Faraday::Error => e
      raise Error, "#{e.class}: #{e.message}"
    end

    def handle(response)
      case response.status
      when 200..299 then response.body.presence || {}
      when 401, 403 then raise AuthenticationError, "Google refused the access token (#{response.status})"
      when 404, 410 then raise NotFoundError, "not found (#{response.status})"
      else raise Error, "Google error #{response.status}"
      end
    end

    def access_token
      if @account.access_token.blank? || @account.access_token_expires_at.nil? ||
         @account.access_token_expires_at.before?(1.minute.from_now)
        token = Oauth.refresh(@account.api_token)
        @account.update!(access_token: token[:access_token], access_token_expires_at: token[:expires_at])
      end
      @account.access_token
    end

    def connection
      @connection ||= Faraday.new("#{BASE_URL}/", headers: { "Content-Type" => "application/json" },
                                                  request: { timeout: 10, open_timeout: 5 }) do |f|
        f.request :retry, max: 3, interval: 1, backoff_factor: 2, retry_statuses: [429, 500, 502, 503, 504],
                          methods: %i[get delete patch]
        f.response :json, content_type: /\bjson$/
      end
    end
  end
end
