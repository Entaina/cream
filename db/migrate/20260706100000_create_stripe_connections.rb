class CreateStripeConnections < ActiveRecord::Migration[8.0]
  def change
    create_table :stripe_connections do |t|
      t.references :workspace, null: false, foreign_key: true, index: { unique: true }
      t.references :user, null: false, foreign_key: true
      t.text :api_key
      t.string :account_label
      t.boolean :sync_enabled, null: false, default: false
      t.datetime :last_synced_at
      t.bigint :sync_cursor
      t.string :last_error

      t.timestamps
    end
  end
end
