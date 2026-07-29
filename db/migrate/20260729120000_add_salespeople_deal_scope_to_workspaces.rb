class AddSalespeopleDealScopeToWorkspaces < ActiveRecord::Migration[8.0]
  def change
    add_column :workspaces, :salespeople_can_view_all_deals, :boolean, null: false, default: false
    add_column :workspaces, :salespeople_can_edit_all_deals, :boolean, null: false, default: false
  end
end
