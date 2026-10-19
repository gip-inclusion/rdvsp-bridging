# Stores an RDV that RDV-SP PUT into a connection's calendar and schedules its push to the provider
module Rdvs
  class Receive < BaseService
    def initialize(connection:, href_name:, ics:)
      @connection = connection
      @href_name = href_name
      @ics = ics
    end

    def call
      event = parse_event
      rdv = @connection.rdvs.find_or_initialize_by(href_name: @href_name)
      result.created = rdv.new_record? || rdv.cancelled?
      rdv.assign_attributes(
        uid: event.uid, starts_at: event.starts_at, ends_at: event.ends_at, payload: event.payload,
        cancelled_at: event.cancelled ? (rdv.cancelled_at || Time.current) : nil, state: "pending", last_error: nil
      )
      rdv.regenerate_etag
      save_record!(rdv)
      PushRdvJob.perform_later(rdv)
      result.rdv = rdv
    end

    private

    def parse_event
      Caldav::IncomingEvent.parse(@ics)
    rescue StandardError => e
      fail!("invalid iCalendar body: #{e.class}")
    end
  end
end
