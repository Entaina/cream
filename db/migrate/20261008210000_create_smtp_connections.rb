class CreateSmtpConnections < ActiveRecord::Migration[8.1]
  def change
    create_table :smtp_connections do |t|
      t.references :workspace, null: false, foreign_key: true, index: {unique: true}
      t.references :user, null: false, foreign_key: true
      t.string :address, null: false
      t.integer :port, null: false, default: 587
      t.string :user_name
      t.text :password
      t.string :domain
      t.string :authentication, null: false, default: "plain"
      t.boolean :enable_starttls_auto, null: false, default: true
      t.string :from_email, null: false
      t.string :from_name
      t.boolean :sender_domain_validated, null: false, default: false

      t.timestamps
    end
  end
end
