class CreateBeehiivConnections < ActiveRecord::Migration[8.1]
  def change
    create_table :beehiiv_connections do |t|
      t.references :workspace, null: false, foreign_key: true, index: { unique: true }
      t.references :user, null: false, foreign_key: true
      t.string :api_key, null: false
      t.string :publication_id, null: false
      t.string :webhook_token, null: false
      t.string :webhook_signing_secret
      t.datetime :last_synced_at
      t.text :last_error
      t.boolean :sync_enabled, null: false, default: true

      t.timestamps
    end

    add_index :beehiiv_connections, :webhook_token, unique: true

    add_column :email_subscriptions, :beehiiv_subscription_id, :string
    add_index :email_subscriptions,
      [ :workspace_id, :beehiiv_subscription_id ],
      unique: true,
      where: "beehiiv_subscription_id IS NOT NULL",
      name: "idx_email_subscriptions_workspace_beehiiv_sub"
  end
end
