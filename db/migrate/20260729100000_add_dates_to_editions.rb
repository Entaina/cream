class AddDatesToEditions < ActiveRecord::Migration[8.1]
  def change
    add_column :editions, :starts_on, :date
    add_column :editions, :ends_on, :date
  end
end
