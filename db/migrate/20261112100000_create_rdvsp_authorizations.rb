class CreateRdvspAuthorizations < ActiveRecord::Migration[8.1]
  def change
    create_table :rdvsp_authorizations do |t|
      t.references :account, null: false, foreign_key: true, index: { unique: true }
      t.bigint :agent_id, null: false
      t.string :agent_email
      t.text :access_token, null: false
      t.text :refresh_token, null: false
      t.datetime :expires_at, null: false
      t.datetime :lost_at
      t.timestamps
    end
  end
end
