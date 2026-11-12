class Account < ApplicationRecord
  PROVIDERS = %w[pipedrive google].freeze
  FAILURE_GRACE_PERIOD = 1.hour

  # Pipedrive: the API token; Google: the OAuth refresh token
  encrypts :api_token
  encrypts :access_token

  has_many :connections, dependent: :destroy
  has_one :rdvsp_authorization, dependent: :destroy
  has_many :imported_usagers, dependent: :delete_all
  has_many :usager_imports, dependent: :delete_all

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
