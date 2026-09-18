class AddTimeZoneToUsersAndWorkspaces < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :time_zone, :string
    add_column :workspaces, :time_zone, :string, null: false, default: "Europe/Madrid"
  end
end
