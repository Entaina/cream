class CreateAlertDeliveries < ActiveRecord::Migration[8.0]
  def change
    create_table :alert_deliveries do |t|
      t.references :alert_rule, null: false, foreign_key: true
      t.references :deal, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :alert_deliveries, %i[alert_rule_id deal_id user_id], unique: true
  end
end
