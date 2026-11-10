class Rdv < ApplicationRecord
  STATES = %w[pending synced failed].freeze

  belongs_to :connection

  validates :href_name, presence: true, uniqueness: { scope: :connection_id }
  validates :state, inclusion: { in: STATES }

  serialize :payload, coder: JSON
  encrypts :payload

  scope :ignored, -> { where.not(ignored_at: nil) }
  scope :cancelled, -> { where.not(cancelled_at: nil) }
  scope :transmitted, -> { where(ignored_at: nil, cancelled_at: nil).where.not(provider_object_id: nil) }

  def cancelled? = cancelled_at.present?

  # Existed before the connection (see Connection#open_baseline!): never pushed to the provider
  def ignored? = ignored_at.present?

  # An ignored RDV is pushed only to remove an activity created before it was ignored
  def needs_push? = !ignored? || provider_object_id.present?

  def regenerate_etag = self.etag = %("#{SecureRandom.hex(8)}")
end
