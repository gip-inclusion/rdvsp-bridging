# The link the team sends an agent to get their CalDAV credentials (docs/ui.md): one per connection at a time, open
# 7 days, and only 15 minutes more once the agent has generated a password through it
module CaldavLink
  extend ActiveSupport::Concern

  LIFETIME = 7.days
  GRACE = 15.minutes

  included do
    # Tokens name the current link by its creation time (to the microsecond), so creating another one spends them
    generates_token_for(:caldav_setup) { caldav_link_issued_at&.utc&.iso8601(6) }
  end

  class_methods do
    def from_caldav_link(token) = find_by_token_for(:caldav_setup, token)&.then { it if it.caldav_link_open? }
  end

  def start_caldav_link! = update!(caldav_link_issued_at: Time.current, caldav_link_used_at: nil)

  def caldav_link_expires_at
    return unless caldav_link_issued_at

    [caldav_link_issued_at + LIFETIME, caldav_link_used_at&.+(GRACE)].compact.min
  end

  def caldav_link_open? = caldav_link_expires_at&.future? || false

  # A new password, which replaces the previous one; the link's first use starts its last 15 minutes
  def use_caldav_link!
    password = self.class.generate_password
    update!(password:, caldav_link_used_at: caldav_link_used_at || Time.current)
    password
  end
end
