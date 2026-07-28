class CreateStripePayments < ActiveRecord::Migration[8.0]
  def change
    create_table :stripe_payments do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :stripe_connection, null: false, foreign_key: true
      t.string :stripe_charge_id, null: false
      t.integer :amount_cents, null: false, default: 0
      t.string :currency, null: false, default: "eur"
      t.string :customer_email
      t.string :customer_name
      t.string :stripe_customer_id
      t.string :description
      t.jsonb :metadata, null: false, default: {}
      t.datetime :paid_at, null: false
      t.boolean :refunded, null: false, default: false
      t.boolean :livemode, null: false, default: true
      t.string :status, null: false, default: "pending_review"
      t.references :deal, foreign_key: true
      t.references :suggested_deal, foreign_key: { to_table: :deals }
      t.references :suggested_person, foreign_key: { to_table: :people }
      t.string :match_confidence
      t.references :matched_by, foreign_key: { to_table: :users }
      t.datetime :matched_at

      t.timestamps
    end
    add_index :stripe_payments, [ :workspace_id, :stripe_charge_id ], unique: true
    add_index :stripe_payments, [ :workspace_id, :status ]
    add_index :stripe_payments, :customer_email
  end
end
