class AddExpiresAtToSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :sessions, :expires_at, :datetime
    add_index :sessions, :expires_at

    up_only do
      execute "UPDATE sessions SET expires_at = CURRENT_TIMESTAMP + INTERVAL '30 days' WHERE expires_at IS NULL"
    end
  end
end
