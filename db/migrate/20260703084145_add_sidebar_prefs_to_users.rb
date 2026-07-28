class AddSidebarPrefsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :sidebar_prefs, :jsonb, default: {}, null: false
  end
end
