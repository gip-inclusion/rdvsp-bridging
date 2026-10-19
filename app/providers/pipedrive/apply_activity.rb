module Pipedrive
  # Applies the current state of one activity to every active connection of its account
  class ApplyActivity
    def initialize(connections_by_user_id)
      @connections_by_user_id = connections_by_user_id
    end

    def call(activity)
      @connections_by_user_id.each_value do |connection|
        times = BusyMapping.new(connection, excluded_activity_ids: excluded_ids_for(connection)).times_for(activity)
        if times
          connection.upsert_busy_block!(activity["id"], **times)
        else
          connection.remove_busy_block!(activity["id"])
        end
      end
    end

    private

    def excluded_ids_for(connection)
      @excluded_ids_for ||= Rdv.joins(:connection).where(connections: { account_id: connection.account_id })
        .where.not(provider_object_id: nil).pluck(:provider_object_id).to_set
    end
  end
end
