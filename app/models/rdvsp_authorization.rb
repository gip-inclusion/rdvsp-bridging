# An RDV-SP agent's OAuth authorization for an account: the bridge calls RDV-SP's API as that agent. The account's own
# (no provider_user_id) serves the import; each Pipedrive user's serves their clicks on "Prendre RDV".
class RdvspAuthorization < ApplicationRecord
  belongs_to :account

  encrypts :access_token
  encrypts :refresh_token

  validates :provider_user_id, uniqueness: { scope: :account_id }
  validates :agent_id, :access_token, :refresh_token, :expires_at, presence: true

  LINK_VALIDITY = 7.days

  # RDV-SP brought back another agent than the one of the Pipedrive user's connection
  class OtherAgent < StandardError
    attr_reader :agent_email

    def initialize(agent_email)
      @agent_email = agent_email
      super("RDV-SP authorized another agent than the connection's")
    end
  end

  def self.link_token(account) = account.signed_id(purpose: :rdvsp_authorization, expires_in: LINK_VALIDITY)

  def self.account_for(token) = Account.find_signed(token, purpose: :rdvsp_authorization)

  # Exchanges the code an agent brought back from RDV-SP, replacing the earlier authorization of the account, or of
  # that Pipedrive user
  def self.authorize!(account:, code:, redirect_uri:, provider_user_id: nil)
    authorization = find_or_initialize_by(account:, provider_user_id:)
    previous_refresh_token = authorization.refresh_token
    authorization.assign_attributes(**Rdvsp::Oauth.exchange_code(code:, redirect_uri:), lost_at: nil)
    agent = Rdvsp::Client.new(authorization).me
    authorization.ensure_connection_agent!(agent["email"])
    authorization.update!(agent_id: agent.fetch("id"), agent_email: agent["email"])
    authorization.revoke(previous_refresh_token)
    authorization
  end

  def lost? = lost_at.present?

  # On a shared computer, RDV-SP may log someone else in silently: a Pipedrive user's authorization must come from the
  # agent of their connection, when there is one. The new token is revoked otherwise.
  def ensure_connection_agent!(email)
    expected = provider_user_id && account.connections.find_by(provider_user_id:)&.agent_email
    return if expected.blank? || email.to_s.strip.casecmp?(expected.strip)

    Rails.logger.warn("RDV-SP authorized another agent than the connection's, for Pipedrive user #{provider_user_id} " \
                      "of account #{account_id}")
    revoke
    raise OtherAgent, email
  end

  def withdraw!
    revoke
    destroy!
  end

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
