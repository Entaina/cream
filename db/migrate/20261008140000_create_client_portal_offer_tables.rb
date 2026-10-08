class CreateClientPortalOfferTables < ActiveRecord::Migration[8.0]
  def change
    create_table :offer_views do |t|
      t.bigint :workspace_id, null: false
      t.bigint :offer_id, null: false
      t.bigint :offer_version_id, null: false
      t.bigint :person_id, null: false
      t.datetime :viewed_at, null: false
      t.bigint :offer_share_link_id
      t.timestamps
    end

    add_index :offer_views, [:offer_id, :viewed_at]
    add_index :offer_views, :offer_version_id
    add_index :offer_views, :person_id
    add_index :offer_views, :workspace_id
    add_foreign_key :offer_views, :workspaces
    add_foreign_key :offer_views, :offers
    add_foreign_key :offer_views, :offer_versions
    add_foreign_key :offer_views, :people

    create_table :offer_share_links do |t|
      t.bigint :workspace_id, null: false
      t.bigint :offer_id, null: false
      t.bigint :person_id, null: false
      t.string :token, null: false
      t.datetime :revoked_at
      t.timestamps
    end

    add_index :offer_share_links, :token, unique: true
    add_index :offer_share_links, [:offer_id, :person_id], unique: true
    add_index :offer_share_links, :workspace_id
    add_foreign_key :offer_share_links, :workspaces
    add_foreign_key :offer_share_links, :offers
    add_foreign_key :offer_share_links, :people

    create_table :offer_access_grants do |t|
      t.bigint :offer_share_link_id, null: false
      t.string :email, null: false
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :used_at
      t.timestamps
    end

    add_index :offer_access_grants, :offer_share_link_id
    add_index :offer_access_grants, [:offer_share_link_id, :token_digest], unique: true,
      name: "index_offer_access_grants_on_share_link_and_digest"
    add_foreign_key :offer_access_grants, :offer_share_links
    add_foreign_key :offer_views, :offer_share_links

    change_table :deal_contacts do |t|
      t.string :source
      t.references :offer_share_link, foreign_key: {on_delete: :nullify}
    end
  end
end
