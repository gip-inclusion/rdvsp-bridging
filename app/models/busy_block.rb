class BusyBlock < ApplicationRecord
  belongs_to :connection

  scope :live, -> { where(deleted_at: nil) }
  scope :deleted, -> { where.not(deleted_at: nil) }
  scope :changed_after, ->(seq) { where(seq: (seq + 1)..) }

  HREF_NAME_FORMAT = %r{\Abusy-(?<id>[^/]+)\.ics\z}

  def self.href_name_for(provider_object_id) = "busy-#{provider_object_id}.ics"

  def self.provider_object_id_from(href_name) = href_name.to_s.match(HREF_NAME_FORMAT)&.[](:id)

  def href_name = self.class.href_name_for(provider_object_id)

  def deleted? = deleted_at.present?

  def etag = %("#{seq}")
end
