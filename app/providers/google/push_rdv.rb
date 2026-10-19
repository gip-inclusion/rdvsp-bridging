module Google
  # Creates, updates or deletes the Google Calendar event mirroring an RDV received from RDV-SP
  class PushRdv < BaseService
    def initialize(rdv:)
      @rdv = rdv
    end

    def call
      @rdv.cancelled? ? delete_event : upsert_event
      @rdv.update!(state: "synced", pushed_at: Time.current, last_error: nil, payload: nil)
    rescue Google::Error => e
      @rdv.update!(state: "failed", last_error: e.message.truncate(1_000))
      raise
    end

    private

    def calendar_id = @rdv.connection.provider_user_id

    def client = @client ||= Client.new(@rdv.connection.account)

    def delete_event
      client.delete_event(calendar_id, @rdv.provider_object_id) if @rdv.provider_object_id
    rescue Google::NotFoundError
      nil
    end

    def upsert_event
      event = update_existing || client.insert_event(calendar_id, attributes)
      @rdv.update!(provider_object_id: event["id"])
    end

    def update_existing
      return if @rdv.provider_object_id.nil?

      event = client.patch_event(calendar_id, @rdv.provider_object_id, attributes.merge(status: "confirmed"))
      event unless event["status"] == "cancelled"
    rescue Google::NotFoundError
      nil
    end

    def attributes
      content = RdvContent.new(@rdv)
      {
        summary: content.subject,
        description: content.text,
        location: content.location,
        start: { dateTime: @rdv.starts_at.utc.iso8601 },
        end: { dateTime: @rdv.ends_at.utc.iso8601 },
        transparency: "opaque",
        extendedProperties: { private: { BusyMapping::RDV_PROPERTY => @rdv.href_name } },
      }.compact
    end
  end
end
