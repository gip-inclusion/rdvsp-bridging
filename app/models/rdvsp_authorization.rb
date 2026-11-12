# An RDV-SP agent's OAuth authorization for an account: the bridge calls RDV-SP's API as that agent
class RdvspAuthorization < ApplicationRecord
  belongs_to :account

  encrypts :access_token
  encrypts :refresh_token

  validates :account_id, uniqueness: true
  validates :agent_id, :access_token, :refresh_token, :expires_at, presence: true

  def lost? = lost_at.present?

  def fresh_access_token
    refresh! if expires_at.before?(1.minute.from_now)
    access_token
  end

  # RDV-SP revokes the old refresh token: the new one is saved before the new access token is used
  def refresh!
    raise Rdvsp::AuthenticationError, "RDV-SP authorization lost: an agent must authorize the bridge again" if lost?

    update!(Rdvsp::Oauth.refresh(refresh_token))
  rescue Rdvsp::AuthenticationError
    update!(lost_at: Time.current) unless lost?
    raise
  end
end
