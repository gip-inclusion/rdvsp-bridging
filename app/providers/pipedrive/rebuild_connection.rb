module Pipedrive
  # Full rebuild of a connection's busy blocks from all the activities its Pipedrive user owns.
  # Catches deletions the incremental refresh cannot see.
  class RebuildConnection < BaseService
    def initialize(connection:)
      @connection = connection
    end

    def call
      mapping = BusyMapping.new(@connection)
      blocks = {}
      Client.new(account.api_token).each_activity(owner_id: @connection.provider_user_id) do |activity|
        times = mapping.times_for(activity)
        blocks[activity["id"].to_s] = times if times
      end
      @connection.replace_busy_blocks!(blocks)
      @connection.prune_tombstones!
      account.record_success!
      result.count = blocks.size
    rescue Pipedrive::Error => e
      account.record_failure!(e)
      fail!(e.message)
    end

    private

    def account = @connection.account
  end
end
