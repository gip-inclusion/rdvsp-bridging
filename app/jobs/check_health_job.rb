# RDV-SP never tells anyone when a calendar stops syncing, so we do
class CheckHealthJob < ApplicationJob
  REALERT_AFTER = 1.day

  def perform
    Account.where.not(failing_since: nil).find_each do |account|
      next unless account.failing_for_too_long?
      next if account.alerted_at&.after?(REALERT_AFTER.ago)

      AlertMailer.account_failing(account).deliver_later
      account.update!(alerted_at: Time.current)
    end
  end
end
