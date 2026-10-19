module Caldav
  # Minimal representation of an RDV received from RDV-SP: we don't keep the original body
  module RdvIcs
    def self.render(rdv)
      calendar = Icalendar::Calendar.new
      calendar.prodid = "-//rdvsp-bridges//FR"
      calendar.event do |event|
        event.uid = rdv.uid.presence || rdv.href_name.delete_suffix(".ics")
        event.dtstamp = Icalendar::Values::DateTime.new(rdv.updated_at.utc)
        event.dtstart = Icalendar::Values::DateTime.new(rdv.starts_at.utc)
        event.dtend = Icalendar::Values::DateTime.new(rdv.ends_at.utc)
        event.summary = "RDV Service Public"
      end
      calendar.to_ical
    end
  end
end
