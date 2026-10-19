module Pipedrive
  # Decides whether a Pipedrive activity blocks a connection's time in RDV-SP, and when.
  # Pipedrive returns due_date/due_time in UTC.
  class BusyMapping
    WINDOW_PAST = 7.days
    WINDOW_FUTURE = 6.months
    DEFAULT_DURATION = 30.minutes
    ALL_DAY_TIME_ZONE = "Europe/Paris".freeze

    def initialize(connection, excluded_activity_ids: nil)
      @connection = connection
      @excluded_activity_ids = excluded_activity_ids
    end

    # => { starts_at:, ends_at: } or nil when the activity must not block time
    def times_for(activity)
      return unless blocking?(activity)

      times = activity["due_time"].present? ? timed(activity) : all_day(activity)
      times if times && in_window?(times)
    end

    private

    def blocking?(activity)
      activity["owner_id"].to_s == @connection.provider_user_id &&
        !activity["is_deleted"] &&
        activity["busy"] != false &&
        activity["due_date"].present? &&
        (activity["due_time"].present? || @connection.include_all_day) &&
        (rdv_type_key.nil? || activity["type"] != rdv_type_key) &&
        excluded_activity_ids.exclude?(activity["id"].to_s)
    end

    def timed(activity)
      starts_at = Time.find_zone("UTC").parse("#{activity['due_date']} #{activity['due_time']}")
      { starts_at:, ends_at: starts_at + duration(activity["duration"]) }
    end

    def all_day(activity)
      day = Date.parse(activity["due_date"])
      zone = Time.find_zone(ALL_DAY_TIME_ZONE)
      { starts_at: zone.local(day.year, day.month, day.day), ends_at: zone.local(day.year, day.month, day.day) + 1.day }
    end

    def duration(value)
      hours, minutes = value.to_s.split(":").map(&:to_i)
      total = (hours.to_i.hours + minutes.to_i.minutes)
      total.positive? ? total : DEFAULT_DURATION
    end

    def in_window?(times) = times[:ends_at] > WINDOW_PAST.ago && times[:starts_at] < WINDOW_FUTURE.from_now

    def rdv_type_key = @connection.account.rdv_activity_type_key.presence

    def excluded_activity_ids
      @excluded_activity_ids ||= Rdv.joins(:connection).where(connections: { account_id: @connection.account_id })
        .where.not(provider_object_id: nil).pluck(:provider_object_id).to_set
    end
  end
end
