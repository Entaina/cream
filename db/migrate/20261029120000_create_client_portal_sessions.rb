class CreateClientPortalSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :client_portal_sessions do |t|
      t.references :workspace, null: false, foreign_key: {on_delete: :cascade}
      t.string :email, null: false
      t.string :token_digest, null: false
      t.boolean :preview, null: false, default: false
      t.datetime :expires_at, null: false
      t.datetime :revoked_at
      t.timestamps
    end

    add_index :client_portal_sessions, :token_digest, unique: true
    add_index :client_portal_sessions, :expires_at
  end
end
