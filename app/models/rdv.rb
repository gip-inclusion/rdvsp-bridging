class Rdv < ApplicationRecord
  STATES = %w[pending synced failed].freeze

  belongs_to :connection

  validates :href_name, presence: true, uniqueness: { scope: :connection_id }
  validates :state, inclusion: { in: STATES }

  serialize :payload, coder: JSON
  encrypts :payload

  scope :ignored, -> { where.not(ignored_at: nil) }

  def cancelled? = cancelled_at.present?

  # Existed before the connection (see Connection#open_baseline!): never pushed to the provider
  def ignored? = ignored_at.present?

  def needs_push? = !ignored?

  def regenerate_etag = self.etag = %("#{SecureRandom.hex(8)}")
end
