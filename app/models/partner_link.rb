# A link the team sends a partner's admin: it opens their account's admin pages, and only those, without a password,
# until revoked (docs/partner-links.md). The token is derived from the record: nothing secret is stored.
class PartnerLink < ApplicationRecord
  belongs_to :account

  generates_token_for(:partner_access)

  validates :label, presence: true

  def self.from_token(token) = find_by_token_for(:partner_access, token)&.then { it if it.active? }

  def active? = revoked_at.nil?

  def revoke! = update!(revoked_at: Time.current)

  def record_use! = increment!(:uses_count, touch: :last_used_at)
end
