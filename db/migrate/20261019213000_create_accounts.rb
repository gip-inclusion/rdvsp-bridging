class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      t.string :provider, null: false, default: "pipedrive"
      t.string :name, null: false
      t.text :api_token, null: false
      t.string :provider_company_id
      t.string :provider_company_domain
      t.boolean :usager_details, null: false, default: false
      t.boolean :link_persons, null: false, default: false
      t.string :alert_email
      t.string :webhook_token, null: false
      t.string :provider_webhook_id
      t.string :rdv_activity_type_key
      t.datetime :refresh_cursor
      t.datetime :refreshed_at
      t.datetime :failing_since
      t.text :last_error
      t.datetime :alerted_at
      t.timestamps
    end
    add_index :accounts, :webhook_token, unique: true
    add_index :accounts, %i[provider provider_company_id], unique: true
  end
end
