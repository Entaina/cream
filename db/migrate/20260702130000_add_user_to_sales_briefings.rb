class AddUserToSalesBriefings < ActiveRecord::Migration[8.0]
  def change
    add_reference :sales_briefings, :user, null: true, foreign_key: true
    add_column :sales_briefings, :wins, :jsonb, null: false, default: []
    add_column :sales_briefings, :misses, :jsonb, null: false, default: []

    remove_index :sales_briefings, [:workspace_id, :briefing_date]

    add_index :sales_briefings, [:workspace_id, :briefing_date],
      unique: true,
      where: "user_id IS NULL",
      name: "index_sales_briefings_team_unique"

    add_index :sales_briefings, [:workspace_id, :user_id, :briefing_date],
      unique: true,
      where: "user_id IS NOT NULL",
      name: "index_sales_briefings_personal_unique"
  end
end
