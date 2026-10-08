class CreateClientPortalLoginGrants < ActiveRecord::Migration[8.0]
  def change
    create_table :client_portal_login_grants do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :email, null: false
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :used_at
      t.timestamps
    end

    add_index :client_portal_login_grants, :token_digest, unique: true
    add_index :client_portal_login_grants, [ :workspace_id, :email, :created_at ]
  end
end
