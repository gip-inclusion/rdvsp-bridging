class Connection < ApplicationRecord
  include SyncCollection

  BASELINE_QUIET = 1.minute
  BASELINE_LIMIT = 15.minutes

  belongs_to :account
  has_many :busy_blocks, dependent: :delete_all
  has_many :busy_block_changes, dependent: :delete_all
  has_many :rdvs, dependent: :destroy

  has_secure_token :public_id
  has_secure_token :username, length: 24

  validates :provider_user_id, presence: true, uniqueness: { scope: :account_id }
  validates :password_digest, presence: true

  scope :active, -> { where(disabled_at: nil) }

  attr_reader :password

  def self.authenticate(username, password)
    connection = active.find_by(username:)
    connection if connection&.password_matches?(password)
  end

  def self.generate_password = SecureRandom.base58(32)

  # Passwords are random (see generate_password), so a fast digest is enough: no bcrypt cost on every CalDAV request
  def self.digest(password) = OpenSSL::Digest::SHA256.hexdigest(password.to_s)

  def password=(value)
    @password = value
    self.password_digest = self.class.digest(value)
  end

  def password_matches?(candidate)
    return legacy_password_matches?(candidate) if password_digest.start_with?("$2")

    ActiveSupport::SecurityUtils.secure_compare(password_digest, self.class.digest(candidate))
  end

  def calendar_path = "/caldav/#{public_id}/calendar/"

  def touch_last_seen!
    update_column(:last_seen_at, Time.current) if last_seen_at.nil? || last_seen_at.before?(1.minute.ago)
  end

  # RDV-SP tests the connection whenever the agent saves their settings, then PUTs every RDV from two weeks back:
  # RDVs first received before a quiet minute has passed existed before the connection (docs/preexisting-rdvs.md)
  def open_baseline!
    now = Time.current
    update_columns(baseline_started_at: now, baseline_until: now + BASELINE_QUIET)
  end

  # Whether the start-up window is open, keeping it open a quiet minute more (never past BASELINE_LIMIT). A single
  # statement, since the bulk export arrives as concurrent requests.
  def extend_open_baseline!
    now = Time.current
    extended = self.class.where(id:, baseline_until: now..).update_all(
      ["baseline_until = LEAST(GREATEST(baseline_until, ?), baseline_started_at + make_interval(secs => ?))",
       now + BASELINE_QUIET, BASELINE_LIMIT.to_i,]
    )
    extended == 1
  end

  private

  # Digests from before SHA-256 were bcrypt: checked once, then replaced
  def legacy_password_matches?(candidate)
    return false unless BCrypt::Password.new(password_digest).is_password?(candidate.to_s)

    update_column(:password_digest, self.class.digest(candidate))
    true
  end
end
