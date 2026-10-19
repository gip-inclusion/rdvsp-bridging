module Pipedrive
  # Incremental refresh: applies every activity updated since the account's cursor to its connections' busy blocks.
  # Deleted activities don't show up here; webhooks and RebuildConnection take care of them.
  class RefreshAccount < BaseService
    CURSOR_OVERLAP = 2.minutes

    def initialize(account:)
      @account = account
    end

    def call
      started_at = Time.current
      connections = @account.connections.active.index_by(&:provider_user_id)
      client.each_activity(updated_since:) { |activity| ApplyActivity.new(connections).call(activity) }
      @account.update!(refresh_cursor: started_at, refreshed_at: Time.current)
      @account.record_success!
    rescue Pipedrive::Error => e
      @account.update!(refreshed_at: Time.current)
      @account.record_failure!(e)
      fail!(e.message)
    end

    private

    def updated_since = (@account.refresh_cursor || 1.day.ago).advance(seconds: -CURSOR_OVERLAP).utc.iso8601

    def client = Client.new(@account.api_token)
  end
end
