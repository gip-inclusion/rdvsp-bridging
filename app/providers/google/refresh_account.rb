module Google
  # Incremental refresh of every calendar of a Google account: deleted events come back as "cancelled"
  class RefreshAccount < BaseService
    CURSOR_OVERLAP = 2.minutes

    def initialize(account:)
      @account = account
    end

    def call
      started_at = Time.current
      updated_min = (@account.refresh_cursor || 1.day.ago) - CURSOR_OVERLAP
      @account.connections.active.find_each do |connection|
        mapping = BusyMapping.new(connection)
        client.each_event(connection.provider_user_id, **Window.bounds, updated_min:) do |event|
          times = mapping.times_for(event)
          times ? connection.upsert_busy_block!(event["id"], **times) : connection.remove_busy_block!(event["id"])
        end
      end
      @account.update!(refresh_cursor: started_at, refreshed_at: Time.current)
      @account.record_success!
    rescue Google::Error => e
      @account.update!(refreshed_at: Time.current)
      @account.record_failure!(e)
      fail!(e.message)
    end

    private

    def client = @client ||= Client.new(@account)
  end
end
