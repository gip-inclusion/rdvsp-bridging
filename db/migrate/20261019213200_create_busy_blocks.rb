class CreateBusyBlocks < ActiveRecord::Migration[8.1]
  def change
    create_table :busy_blocks do |t|
      t.references :connection, null: false, foreign_key: true, index: false
      t.string :provider_object_id, null: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.datetime :deleted_at
      t.bigint :seq, null: false
      t.timestamps
    end
    add_index :busy_blocks, %i[connection_id provider_object_id], unique: true
    add_index :busy_blocks, %i[connection_id seq]

    # Append-only counter: its ids give busy blocks a global, monotonic change sequence (used in sync tokens)
    create_table :busy_block_changes do |t|
      t.references :connection, null: false, foreign_key: { on_delete: :cascade }
      t.datetime :created_at, null: false
    end
  end
end
