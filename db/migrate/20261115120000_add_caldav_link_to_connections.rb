class AddCaldavLinkToConnections < ActiveRecord::Migration[8.1]
  def change
    add_column :connections, :caldav_link_issued_at, :datetime
    add_column :connections, :caldav_link_used_at, :datetime
  end
end
