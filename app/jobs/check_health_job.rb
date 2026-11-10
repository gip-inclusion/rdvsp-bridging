# RDV-SP never tells anyone when a calendar stops syncing, so we do
class CheckHealthJob < ApplicationJob
  REALERT_AFTER = 1.day
  # RDV-SP polls each calendar at least every 15 minutes
  SILENCE_THRESHOLD = 30.minutes

  # Also sent to the error tracker, since alert e-mails may not be configured
  class ConnectionsSilent < StandardError; end

  def perform
    alert_failing_accounts
    alert_silent_connections
  end

  private

  def alert_failing_accounts
    Account.where.not(failing_since: nil).where(id: Connection.active.select(:account_id)).find_each do |account|
      next unless account.failing_for_too_long?
      next if account.alerted_at&.after?(REALERT_AFTER.ago)

      AlertMailer.account_failing(account).deliver_later
      account.update!(alerted_at: Time.current)
    end
  end

  # Requests that fail before reaching a controller (the 2026-11-10 outage) only show as RDV-SP's silence
  def alert_silent_connections
    connections = Connection.active.where(last_seen_at: ...SILENCE_THRESHOLD.ago).select { needs_silence_alert?(it) }
    return if connections.empty?

    message = "RDV-SP has not polled connection(s) #{connections.map(&:id).join(', ')} " \
              "for over #{SILENCE_THRESHOLD.in_minutes.to_i} minutes"
    Rails.logger.error("[CheckHealthJob] #{message}")
    Rails.error.report(ConnectionsSilent.new(message), handled: true, severity: :error)
    AlertMailer.connections_silent(connections).deliver_later
    Connection.where(id: connections.map(&:id)).update_all(silence_alerted_at: Time.current)
  end

  # Once per silence, then daily
  def needs_silence_alert?(connection)
    alerted_at = connection.silence_alerted_at
    alerted_at.nil? || alerted_at.before?(connection.last_seen_at) || !alerted_at.after?(REALERT_AFTER.ago)
  end
end
