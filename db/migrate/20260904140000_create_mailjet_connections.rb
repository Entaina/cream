class CreateMailjetConnections < ActiveRecord::Migration[8.1]
  def change
    create_table :mailjet_connections do |t|
      t.references :workspace, null: false, foreign_key: true, index: {unique: true}
      t.references :user, null: false, foreign_key: true
      t.text :api_key
      t.text :secret_key
      t.string :from_email
      t.string :from_name
      t.string :webhook_token, null: false

      t.timestamps
    end

    add_index :mailjet_connections, :webhook_token, unique: true
  end
end
