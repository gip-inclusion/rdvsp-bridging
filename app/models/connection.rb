class Connection < ApplicationRecord
  include SyncCollection

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

  private

  # Digests from before SHA-256 were bcrypt: checked once, then replaced
  def legacy_password_matches?(candidate)
    return false unless BCrypt::Password.new(password_digest).is_password?(candidate.to_s)

    update_column(:password_digest, self.class.digest(candidate))
    true
  end
end
