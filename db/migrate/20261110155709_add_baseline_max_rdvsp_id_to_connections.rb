class AddBaselineMaxRdvspIdToConnections < ActiveRecord::Migration[8.1]
  def change
    add_column :connections, :baseline_max_rdvsp_id, :bigint
  end
end
