module Pipedrive
  # Re-fetches one activity (after a webhook) and applies it. Deleted activities are still returned, flagged.
  class SyncActivity < BaseService
    def initialize(account:, activity_id:)
      @account = account
      @activity_id = activity_id
    end

    def call
      activity = fetch_activity
      ApplyActivity.new(@account.connections.active.index_by(&:provider_user_id)).call(activity)
    end

    private

    def fetch_activity
      Client.new(@account.api_token).activity(@activity_id)
    rescue Pipedrive::NotFoundError
      { "id" => @activity_id, "is_deleted" => true }
    rescue Pipedrive::Error => e
      @account.record_failure!(e)
      fail!(e.message)
    end
  end
end
