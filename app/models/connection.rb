class Connection < ApplicationRecord
  include SyncCollection

  belongs_to :account
  has_many :busy_blocks, dependent: :delete_all
  has_many :busy_block_changes, dependent: :delete_all
  has_many :rdvs, dependent: :destroy

  has_secure_password
  has_secure_token :public_id
  has_secure_token :username, length: 24

  validates :provider_user_id, presence: true, uniqueness: { scope: :account_id }

  scope :active, -> { where(disabled_at: nil) }

  def self.authenticate(username, password)
    active.find_by(username:)&.authenticate(password) || nil
  end

  def self.generate_password = SecureRandom.base58(32)

  def calendar_path = "/caldav/#{public_id}/calendar/"

  def touch_last_seen!
    update_column(:last_seen_at, Time.current) if last_seen_at.nil? || last_seen_at.before?(1.minute.ago)
  end
end
