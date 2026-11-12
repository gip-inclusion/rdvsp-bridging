class CreateImportedUsagers < ActiveRecord::Migration[8.1]
  def change
    create_table :imported_usagers do |t|
      t.references :account, null: false, foreign_key: true, index: false
      t.references :usager_import, foreign_key: { on_delete: :nullify }
      t.string :provider_person_id, null: false
      t.bigint :rdvsp_user_id, null: false
      t.bigint :rdvsp_organisation_id, null: false
      t.timestamps
      t.index %i[account_id provider_person_id], unique: true
    end
  end
end
