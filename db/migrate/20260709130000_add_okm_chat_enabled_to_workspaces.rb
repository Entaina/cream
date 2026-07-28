class AddOkmChatEnabledToWorkspaces < ActiveRecord::Migration[8.0]
  def up
    add_column :workspaces, :okm_chat_enabled, :boolean, null: false, default: false

    if ENV["CREAM_ORGANIZATION_WORKSPACE_NAME"].present?
      slug = ENV["CREAM_ORGANIZATION_WORKSPACE_NAME"].parameterize
      execute(ActiveRecord::Base.sanitize_sql_array([
        "UPDATE workspaces SET okm_chat_enabled = TRUE WHERE slug = ?", slug
      ]))
    end
  end

  def down
    remove_column :workspaces, :okm_chat_enabled
  end
end
