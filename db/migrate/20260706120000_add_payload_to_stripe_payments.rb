class AddPayloadToStripePayments < ActiveRecord::Migration[8.0]
  def change
    add_column :stripe_payments, :payload, :jsonb, null: false, default: {}
  end
end
