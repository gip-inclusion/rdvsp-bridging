module Google
  # Decides whether a Google Calendar event (an expanded instance) blocks a connection's time in RDV-SP, and when
  class BusyMapping
    IGNORED_TYPES = %w[workingLocation birthday].freeze
    ALL_DAY_TIME_ZONE = "Europe/Paris".freeze
    RDV_PROPERTY = "rdvsp_bridging_rdv".freeze

    def initialize(connection)
      @connection = connection
    end

    # => { starts_at:, ends_at: } or nil when the event must not block time
    def times_for(event)
      return unless blocking?(event)

      event.dig("start", "dateTime") ? timed(event) : all_day(event)
    end

    private

    def blocking?(event)
      event["status"] != "cancelled" &&
        event["transparency"] != "transparent" &&
        IGNORED_TYPES.exclude?(event["eventType"]) &&
        !declined?(event) &&
        event.dig("extendedProperties", "private", RDV_PROPERTY).nil? &&
        (event.dig("start", "dateTime") || (@connection.include_all_day && event.dig("start", "date")))
    end

    def declined?(event)
      event.fetch("attendees", []).any? { it["self"] && it["responseStatus"] == "declined" }
    end

    def timed(event)
      { starts_at: Time.zone.parse(event.dig("start", "dateTime")),
        ends_at: Time.zone.parse(event.dig("end", "dateTime")), }
    end

    def all_day(event)
      zone = Time.find_zone(ALL_DAY_TIME_ZONE)
      { starts_at: zone.parse(event.dig("start", "date")), ends_at: zone.parse(event.dig("end", "date")) }
    end
  end
end
