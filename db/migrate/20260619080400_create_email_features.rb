class CreateEmailFeatures < ActiveRecord::Migration[8.1]
  def change
    create_table :email_snippets do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :subject
      t.text :body, null: false
      t.boolean :shared, default: false, null: false

      t.timestamps
    end

    create_table :email_messages do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :record, null: false, polymorphic: true
      t.string :to_address, null: false
      t.string :subject, null: false
      t.text :body, null: false
      t.string :status, default: "sent", null: false
      t.string :tracking_token
      t.datetime :opened_at
      t.integer :clicks_count, default: 0, null: false
      t.string :mail_merge_batch_id

      t.timestamps
    end

    add_index :email_messages, :tracking_token, unique: true

    create_table :gmail_connections do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :access_token
      t.text :refresh_token
      t.datetime :expires_at
      t.boolean :sync_enabled, default: false, null: false
      t.datetime :last_synced_at

      t.timestamps
    end

    add_index :gmail_connections, [:workspace_id, :user_id], unique: true
  end
end
