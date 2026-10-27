class AddEmailVerificationToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :email_verified_at, :datetime
    add_column :users, :pending_workspace_name, :string

    # Accounts created before confirmation existed already proved they could sign in.
    execute "UPDATE users SET email_verified_at = CURRENT_TIMESTAMP WHERE email_verified_at IS NULL"
  end

  def down
    remove_column :users, :pending_workspace_name
    remove_column :users, :email_verified_at
  end
end
