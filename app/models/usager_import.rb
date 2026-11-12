# One run of the import of a partner's beneficiaries into an RDV-SP organisation
class UsagerImport < ApplicationRecord
  STATES = %w[queued running done failed].freeze

  belongs_to :account
  has_many :imported_usagers, dependent: :nullify

  validates :state, inclusion: { in: STATES }
  validates :rdvsp_organisation_id, :field_key, :option_id, :active_since, presence: true
end
