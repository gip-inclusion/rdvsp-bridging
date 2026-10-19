class SyncActivityJob < ApplicationJob
  def perform(account, activity_id)
    Pipedrive::SyncActivity.call(account:, activity_id:)
  end
end
