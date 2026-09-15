class CreateSalesBriefings < ActiveRecord::Migration[8.0]
  def change
    create_table :sales_briefings do |t|
      t.references :workspace, null: false, foreign_key: true
      t.date :briefing_date, null: false
      t.text :summary
      t.jsonb :items, null: false, default: []
      t.datetime :generated_at, null: false

      t.timestamps
    end

    add_index :sales_briefings, [:workspace_id, :briefing_date], unique: true
  end
end
