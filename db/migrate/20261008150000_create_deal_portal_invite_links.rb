class CreateDealPortalInviteLinks < ActiveRecord::Migration[8.0]
  def change
    create_table :deal_portal_invite_links do |t|
      t.bigint :workspace_id, null: false
      t.bigint :deal_id, null: false
      t.string :token, null: false
      t.datetime :revoked_at
      t.timestamps
    end

    add_index :deal_portal_invite_links, :token, unique: true
    add_index :deal_portal_invite_links, :deal_id, unique: true
    add_index :deal_portal_invite_links, :workspace_id
    add_foreign_key :deal_portal_invite_links, :workspaces
    add_foreign_key :deal_portal_invite_links, :deals

    create_table :deal_portal_access_grants do |t|
      t.bigint :deal_portal_invite_link_id, null: false
      t.string :email, null: false
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :used_at
      t.timestamps
    end

    add_index :deal_portal_access_grants, :deal_portal_invite_link_id
    add_index :deal_portal_access_grants, [:deal_portal_invite_link_id, :token_digest],
      unique: true, name: "index_deal_portal_access_grants_on_invite_and_digest"
    add_foreign_key :deal_portal_access_grants, :deal_portal_invite_links
  end
end
