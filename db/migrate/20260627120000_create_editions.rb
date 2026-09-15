class CreateEditions < ActiveRecord::Migration[8.1]
  def change
    create_table :editions do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :name, null: false
      t.timestamps
    end
    add_index :editions, [:workspace_id, :name], unique: true

    add_reference :deal_products, :edition, foreign_key: true
  end
end
