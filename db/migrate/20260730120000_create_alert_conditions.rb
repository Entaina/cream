class CreateAlertConditions < ActiveRecord::Migration[8.0]
  def change
    create_table :alert_conditions do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :alert_rule, null: false, foreign_key: true
      t.string :field, null: false
      t.string :operator, null: false, default: "eq"
      t.string :compare_value
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end
  end
end
