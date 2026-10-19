class AddOauthTokensToAccounts < ActiveRecord::Migration[8.1]
  def change
    change_table :accounts, bulk: true do |t|
      t.text :access_token
      t.datetime :access_token_expires_at
    end
  end
end
