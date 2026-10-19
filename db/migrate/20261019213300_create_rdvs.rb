class CreateRdvs < ActiveRecord::Migration[8.1]
  def change
    create_table :rdvs do |t|
      t.references :connection, null: false, foreign_key: true, index: false
      t.string :href_name, null: false
      t.string :uid
      t.datetime :starts_at
      t.datetime :ends_at
      t.text :payload
      t.string :etag, null: false
      t.string :provider_object_id
      t.string :provider_person_id
      t.string :state, null: false, default: "pending"
      t.datetime :cancelled_at
      t.datetime :pushed_at
      t.text :last_error
      t.timestamps
    end
    add_index :rdvs, %i[connection_id href_name], unique: true
    add_index :rdvs, :provider_object_id
  end
end
