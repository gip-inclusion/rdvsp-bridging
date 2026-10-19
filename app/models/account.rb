class Account < ApplicationRecord
  PROVIDERS = %w[pipedrive].freeze
  FAILURE_GRACE_PERIOD = 1.hour

  encrypts :api_token

  has_many :connections, dependent: :destroy

  validates :provider, inclusion: { in: PROVIDERS }
  validates :name, :api_token, presence: true

  has_secure_token :webhook_token

  def failing? = failing_since.present?

  def failing_for_too_long? = failing? && failing_since.before?(FAILURE_GRACE_PERIOD.ago)

  def record_failure!(error)
    update!(failing_since: failing_since || Time.current, last_error: error.message.truncate(1_000))
  end

  def record_success!
    update!(failing_since: nil, last_error: nil, alerted_at: nil) if failing? || alerted_at?
  end
end
