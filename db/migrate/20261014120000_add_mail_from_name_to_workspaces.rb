class AddMailFromNameToWorkspaces < ActiveRecord::Migration[8.1]
  def change
    add_column :workspaces, :mail_from_name, :string
  end
end
