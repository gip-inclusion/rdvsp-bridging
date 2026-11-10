module Caldav
  # An event RDV-SP PUTs into the calendar
  IncomingEvent = Data.define(:uid, :starts_at, :ends_at, :summary, :description, :location, :cancelled) do
    def self.parse(ics)
      event = Icalendar::Calendar.parse(ics).first&.events&.first
      raise ArgumentError, "no VEVENT" if event.nil? || event.dtstart.nil?

      starts_at = event.dtstart.to_time.utc
      new(
        uid: event.uid.to_s,
        starts_at:,
        ends_at: event.dtend&.to_time&.utc || (starts_at + 30.minutes),
        summary: event.summary.to_s,
        description: event.description.to_s,
        location: event.location.to_s,
        cancelled: event.status.to_s.casecmp?("CANCELLED")
      )
    end

    def payload = { "summary" => summary, "description" => description, "location" => location }

    # From RDV-SP's "Voir sur …" link, before the free-text context (see RdvContent)
    def rdvsp_id = description.split(RdvContent::CONTEXT, 2).first.to_s[RdvContent::RDVSP_RDV_PATH, 1]&.to_i
  end
end
