# Empty for the account's authorization (the import's), the Pipedrive user id for an agent's (the Prendre RDV button's)
class AddProviderUserIdToRdvspAuthorizations < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :rdvsp_authorizations, :provider_user_id, :string, if_not_exists: true
    add_index :rdvsp_authorizations, %i[account_id provider_user_id], unique: true, algorithm: :concurrently
    add_index :rdvsp_authorizations, :account_id, name: "index_rdvsp_authorizations_on_account", unique: true,
                                                  where: "provider_user_id IS NULL", algorithm: :concurrently
    remove_index :rdvsp_authorizations, :account_id, unique: true, name: "index_rdvsp_authorizations_on_account_id",
                                                     algorithm: :concurrently
  end
end
