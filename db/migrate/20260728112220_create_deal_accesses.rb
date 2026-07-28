class CreateDealAccesses < ActiveRecord::Migration[8.1]
  def change
    create_table :deal_accesses do |t|
      t.references :deal, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :deal_accesses, %i[deal_id user_id], unique: true
  end
end
