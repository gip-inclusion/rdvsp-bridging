# An RDV-SP agent's OAuth authorization for an account: the bridge calls RDV-SP's API as that agent
class RdvspAuthorization < ApplicationRecord
  belongs_to :account

  encrypts :access_token
  encrypts :refresh_token

  validates :account_id, uniqueness: true
  validates :agent_id, :access_token, :refresh_token, :expires_at, presence: true

  def lost? = lost_at.present?
end
