module Pipedrive
  # Pipedrive activity attributes for an RDV (content rules in RdvContent)
  class RdvActivity
    def initialize(rdv, person_id: nil)
      @rdv = rdv
      @content = RdvContent.new(rdv)
      @account = rdv.connection.account
      @person_id = person_id
    end

    def attributes
      duration = ((@rdv.ends_at - @rdv.starts_at) / 60).round.clamp(1, (24 * 60) - 1)
      {
        subject: @content.subject,
        type: @account.rdv_activity_type_key.presence || "meeting",
        owner_id: Integer(@rdv.connection.provider_user_id),
        due_date: @rdv.starts_at.utc.to_date.iso8601,
        due_time: @rdv.starts_at.utc.strftime("%H:%M"),
        duration: format("%<hours>02d:%<minutes>02d", hours: duration / 60, minutes: duration % 60),
        busy: true,
        done: false,
        note: @content.html,
        location: @content.location&.then { { value: it } },
        participants: @person_id ? [{ person_id: Integer(@person_id), primary: true }] : nil,
      }.compact
    end
  end
end
