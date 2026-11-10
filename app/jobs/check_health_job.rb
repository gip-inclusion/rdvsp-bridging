# RDV-SP never tells anyone when a calendar stops syncing, so we do
class CheckHealthJob < ApplicationJob
  REALERT_AFTER = 1.day
  # RDV-SP's own schedule for importing every calendar (config/initializers/good_job.rb, production branch), in
  # minutes after midnight, Paris time: every 30 minutes from 05:00 to 06:30, every 10 from 07:00 to 19:50, every 30
  # from 20:00 to 23:30, nothing at night
  RDVSP_IMPORTS = [*(300..390).step(30), *(420..1190).step(10), *(1200..1410).step(30)].freeze
  RDVSP_TIME_ZONE = "Europe/Paris".freeze
  # Its import jobs wait in a queue (latency_5m) and are staggered by a second per calendar
  RDVSP_IMPORT_DELAY = 10.minutes
  MISSED_IMPORTS = 2

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
    connections = Connection.active.where(last_seen_at: ...RDVSP_IMPORT_DELAY.ago)
      .select { silent?(it) && needs_silence_alert?(it) }
    return if connections.empty?

    message = "RDV-SP missed #{MISSED_IMPORTS} scheduled imports of connection(s) #{connections.map(&:id).join(', ')}"
    Rails.logger.error("[CheckHealthJob] #{message}")
    Rails.error.report(ConnectionsSilent.new(message), handled: true, severity: :error)
    AlertMailer.connections_silent(connections).deliver_later
    Connection.where(id: connections.map(&:id)).update_all(silence_alerted_at: Time.current)
  end

  def silent?(connection)
    missed_imports(after: connection.last_seen_at, before: RDVSP_IMPORT_DELAY.ago) >= MISSED_IMPORTS
  end

  def missed_imports(after:, before:)
    return MISSED_IMPORTS if before - after > 1.day

    zone = Time.find_zone(RDVSP_TIME_ZONE)
    (after.in_time_zone(zone).to_date..before.in_time_zone(zone).to_date).sum do |day|
      RDVSP_IMPORTS.count do |minute|
        import = zone.local(day.year, day.month, day.day, minute / 60, minute % 60)
        import > after && import <= before
      end
    end
  end

  # Once per silence, then daily
  def needs_silence_alert?(connection)
    alerted_at = connection.silence_alerted_at
    alerted_at.nil? || alerted_at.before?(connection.last_seen_at) || !alerted_at.after?(REALERT_AFTER.ago)
  end
end
