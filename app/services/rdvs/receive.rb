# Stores an RDV that RDV-SP PUT into a connection's calendar and schedules its push to the provider, unless the RDV
# existed before the connection (classified once, at its first PUT)
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
      rdv.ignored_at = Time.current if rdv.new_record? && existed_before_connection?(event)
      rdv.assign_attributes(
        uid: event.uid, starts_at: event.starts_at, ends_at: event.ends_at,
        payload: rdv.ignored? ? nil : event.payload, rdvsp_id: event.rdvsp_id || rdv.rdvsp_id,
        cancelled_at: event.cancelled ? (rdv.cancelled_at || Time.current) : nil,
        state: rdv.needs_push? ? "pending" : "synced", last_error: nil
      )
      rdv.regenerate_etag
      save_record!(rdv)
      @connection.raise_baseline_watermark!(rdv.rdvsp_id) if rdv.ignored?
      PushRdvJob.perform_later(rdv) if rdv.needs_push?
      result.rdv = rdv
    end

    private

    def existed_before_connection?(event)
      @connection.extend_open_baseline! || @connection.below_baseline_watermark?(event.rdvsp_id)
    end

    def parse_event
      Caldav::IncomingEvent.parse(@ics)
    rescue StandardError => e
      fail!("invalid iCalendar body: #{e.class}")
    end
  end
end
