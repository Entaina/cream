class AddOkmConfigToWorkspaces < ActiveRecord::Migration[8.0]
  def change
    add_column :workspaces, :okm_drive_id, :string
    add_column :workspaces, :okm_service_account_key, :text
  end
end
