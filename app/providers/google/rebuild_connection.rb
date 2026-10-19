module Google
  class RebuildConnection < BaseService
    def initialize(connection:)
      @connection = connection
    end

    def call
      mapping = BusyMapping.new(@connection)
      blocks = {}
      Client.new(account).each_event(@connection.provider_user_id, **Window.bounds) do |event|
        times = mapping.times_for(event)
        blocks[event["id"]] = times if times
      end
      @connection.replace_busy_blocks!(blocks)
      @connection.prune_tombstones!
      account.record_success!
      result.count = blocks.size
    rescue Google::Error => e
      account.record_failure!(e)
      fail!(e.message)
    end

    private

    def account = @connection.account
  end
end
