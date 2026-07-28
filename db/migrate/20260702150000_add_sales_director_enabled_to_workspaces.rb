class AddSalesDirectorEnabledToWorkspaces < ActiveRecord::Migration[8.0]
  def up
    add_column :workspaces, :sales_director_enabled, :boolean, null: false, default: false

    if ENV["CREAM_ORGANIZATION_WORKSPACE_NAME"].present?
      slug = ENV["CREAM_ORGANIZATION_WORKSPACE_NAME"].parameterize
      execute(ActiveRecord::Base.sanitize_sql_array([
        "UPDATE workspaces SET sales_director_enabled = TRUE WHERE slug = ?", slug
      ]))
    end
  end

  def down
    remove_column :workspaces, :sales_director_enabled
  end
end
