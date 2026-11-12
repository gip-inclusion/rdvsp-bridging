# An RDV-SP agent's OAuth authorization for an account: the bridge calls RDV-SP's API as that agent
class RdvspAuthorization < ApplicationRecord
  belongs_to :account

  encrypts :access_token
  encrypts :refresh_token

  validates :account_id, uniqueness: true
  validates :agent_id, :access_token, :refresh_token, :expires_at, presence: true

  LINK_VALIDITY = 7.days

  def self.link_token(account) = account.signed_id(purpose: :rdvsp_authorization, expires_in: LINK_VALIDITY)

  def self.account_for(token) = Account.find_signed(token, purpose: :rdvsp_authorization)

  # Exchanges the code an agent brought back from RDV-SP, replacing the account's earlier authorization
  def self.authorize!(account:, code:, redirect_uri:)
    authorization = account.rdvsp_authorization || account.build_rdvsp_authorization
    previous_refresh_token = authorization.refresh_token
    authorization.assign_attributes(**Rdvsp::Oauth.exchange_code(code:, redirect_uri:), lost_at: nil)
    agent = Rdvsp::Client.new(authorization).me
    authorization.update!(agent_id: agent.fetch("id"), agent_email: agent["email"])
    authorization.revoke(previous_refresh_token)
    authorization
  end

  def lost? = lost_at.present?

  # Best effort: RDV-SP forgets the token anyway when it is replaced, 30 days later
  def revoke(token = refresh_token)
    Rdvsp::Oauth.revoke(token) if token.present?
  rescue Rdvsp::Error => e
    Rails.logger.warn("RDV-SP token revocation failed for account #{account_id}: #{e.message}")
  end

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
