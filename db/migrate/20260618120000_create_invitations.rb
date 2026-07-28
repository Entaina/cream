class CreateInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :invitations do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :email_address, null: false
      t.string :role, null: false, default: "member"
      t.string :token_digest, null: false
      t.references :invited_by, null: false, foreign_key: { to_table: :users }
      t.datetime :accepted_at
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_index :invitations, :token_digest, unique: true
    add_index :invitations, %i[workspace_id email_address],
      unique: true,
      where: "accepted_at IS NULL",
      name: "index_invitations_pending_on_workspace_and_email"
  end
end
