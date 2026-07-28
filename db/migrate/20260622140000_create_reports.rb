class CreateReports < ActiveRecord::Migration[8.1]
  def change
    create_table :reports do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :record_type, null: false
      t.string :metric, null: false
      t.string :group_by, null: false
      t.string :date_range, null: false, default: "all"
      t.boolean :shared, null: false, default: false
      t.timestamps
    end
  end
end
