class AddOmniauthToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :provider, :string
    add_column :users, :uid, :string
    add_index :users, %i[provider uid], unique: true, where: "provider IS NOT NULL AND uid IS NOT NULL"
  end
end
