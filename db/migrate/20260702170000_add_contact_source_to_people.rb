class AddContactSourceToPeople < ActiveRecord::Migration[8.0]
  def change
    add_column :people, :source, :string
    add_column :people, :first_contact_on, :date
  end
end
