class Rdv < ApplicationRecord
  STATES = %w[pending synced failed].freeze

  belongs_to :connection

  validates :href_name, presence: true, uniqueness: { scope: :connection_id }
  validates :state, inclusion: { in: STATES }

  serialize :payload, coder: JSON
  encrypts :payload

  def cancelled? = cancelled_at.present?

  def regenerate_etag = self.etag = %("#{SecureRandom.hex(8)}")
end
