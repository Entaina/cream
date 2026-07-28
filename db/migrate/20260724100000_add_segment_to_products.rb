class AddSegmentToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :segment, :string
  end
end
