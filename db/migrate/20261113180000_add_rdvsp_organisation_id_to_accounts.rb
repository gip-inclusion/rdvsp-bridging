class AddRdvspOrganisationIdToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :rdvsp_organisation_id, :bigint
  end
end
