class CreatePartnerLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :partner_links do |t|
      t.references :account, null: false, foreign_key: true
      t.string :label, null: false
      t.integer :uses_count, null: false, default: 0
      t.datetime :last_used_at
      t.datetime :revoked_at
      t.timestamps
    end
  end
end
