class AddStartUpWindowToConnections < ActiveRecord::Migration[8.1]
  def change
    add_column :connections, :baseline_started_at, :datetime
    add_column :connections, :baseline_until, :datetime
    add_column :rdvs, :ignored_at, :datetime
  end
end
