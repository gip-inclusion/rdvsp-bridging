# A Pipedrive person the bridge created as an RDV-SP usager: ids only, no personal data
class ImportedUsager < ApplicationRecord
  belongs_to :account
  belongs_to :usager_import, optional: true

  validates :provider_person_id, presence: true, uniqueness: { scope: :account_id }
  validates :rdvsp_user_id, :rdvsp_organisation_id, presence: true
end
