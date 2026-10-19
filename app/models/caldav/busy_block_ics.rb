module Caldav
  # The iCalendar representation of busy blocks: times only, never the provider's subject or notes
  module BusyBlockIcs
    def self.render(*blocks)
      calendar = Icalendar::Calendar.new
      calendar.prodid = "-//rdvsp-bridges//FR"
      blocks.each do |block|
        calendar.event do |event|
          event.uid = "#{block.href_name.delete_suffix('.ics')}-#{block.connection_id}@rdvsp-bridges"
          event.dtstamp = Icalendar::Values::DateTime.new(block.updated_at.utc)
          event.dtstart = Icalendar::Values::DateTime.new(block.starts_at.utc)
          event.dtend = Icalendar::Values::DateTime.new(block.ends_at.utc)
          event.summary = "Occupé"
          event.transp = "OPAQUE"
        end
      end
      calendar.to_ical
    end
  end
end
