class CreateAlertRules < ActiveRecord::Migration[8.0]
  def change
    create_table :alert_rules do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :name, null: false
      t.string :trigger_field, null: false
      t.integer :offset_days, null: false, default: 0
      t.jsonb :conditions, null: false, default: []
      t.string :recipient, null: false, default: "deal_owner"
      t.boolean :active, null: false, default: true

      t.timestamps
    end
  end
end
