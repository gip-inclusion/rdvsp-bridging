class CreateUsagerImports < ActiveRecord::Migration[8.1]
  def change
    create_table :usager_imports do |t|
      t.references :account, null: false, foreign_key: true
      t.bigint :rdvsp_organisation_id, null: false
      t.string :field_key, null: false
      t.string :option_id, null: false
      t.date :active_since, null: false
      t.string :state, null: false, default: "queued"
      t.jsonb :counts, null: false, default: {}
      t.jsonb :rejections, null: false, default: {}
      t.text :error
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
    end
  end
end
