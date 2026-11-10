class AddSilenceAlertedAtToConnections < ActiveRecord::Migration[8.1]
  def change
    add_column :connections, :silence_alerted_at, :datetime
  end
end
