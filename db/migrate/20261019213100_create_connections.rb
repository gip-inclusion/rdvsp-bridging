class CreateConnections < ActiveRecord::Migration[8.1]
  def change
    create_table :connections do |t|
      t.references :account, null: false, foreign_key: true
      t.string :provider_user_id, null: false
      t.string :provider_user_name
      t.string :agent_email
      t.string :public_id, null: false
      t.string :username, null: false
      t.string :password_digest, null: false
      t.boolean :include_all_day, null: false, default: false
      t.integer :sync_generation, null: false, default: 1
      t.bigint :pruned_through_seq, null: false, default: 0
      t.datetime :rebuilt_at
      t.datetime :last_seen_at
      t.datetime :disabled_at
      t.timestamps
    end
    add_index :connections, :public_id, unique: true
    add_index :connections, :username, unique: true
    add_index :connections, %i[account_id provider_user_id], unique: true
  end
end
