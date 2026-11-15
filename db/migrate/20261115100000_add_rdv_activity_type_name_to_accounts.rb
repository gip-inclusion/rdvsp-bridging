class AddRdvActivityTypeNameToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :rdv_activity_type_name, :string
  end
end
