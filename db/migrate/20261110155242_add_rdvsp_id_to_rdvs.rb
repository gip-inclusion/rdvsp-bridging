class AddRdvspIdToRdvs < ActiveRecord::Migration[8.1]
  def change
    add_column :rdvs, :rdvsp_id, :bigint
  end
end
