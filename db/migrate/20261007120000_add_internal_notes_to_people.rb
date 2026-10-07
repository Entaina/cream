class AddInternalNotesToPeople < ActiveRecord::Migration[8.0]
  def change
    add_column :people, :internal_notes, :text
  end
end
