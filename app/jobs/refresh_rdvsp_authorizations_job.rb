# RDV-SP deletes an access token 30 days after it was issued once the same agent holds a newer one for the bridge's
# application (CronJob::DestroyOldOauthObjects): an agent with both the account's authorization and their own for
# "Prendre RDV" would lose the one they leave idle. A refresh issues a new token.
class RefreshRdvspAuthorizationsJob < ApplicationJob
  REFRESH_AFTER = 20.days

  def perform
    RdvspAuthorization.where(lost_at: nil, expires_at: ...REFRESH_AFTER.ago).find_each do |authorization|
      authorization.refresh!
    rescue Rdvsp::Error => e
      Rails.logger.warn("RDV-SP authorization #{authorization.id} not refreshed: #{e.message}")
    end
  end
end
