class AddBroughtByToPeople < ActiveRecord::Migration[8.0]
  def change
    add_reference :people, :brought_by, foreign_key: { to_table: :users }
  end
end
