class CreateCommentsAndNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :comments do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :commentable, null: false, polymorphic: true
      t.references :user, null: false, foreign_key: true
      t.references :parent, foreign_key: {to_table: :comments}
      t.text :body, null: false

      t.timestamps
    end

    create_table :notifications do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :actor, foreign_key: {to_table: :users}
      t.string :kind, null: false
      t.string :title, null: false
      t.text :body
      t.string :url
      t.datetime :read_at

      t.timestamps
    end

    add_index :notifications, [:user_id, :read_at, :created_at]
  end
end
