class AddReferenceTypeToCustomFields < ActiveRecord::Migration[8.0]
  def change
    add_column :custom_fields, :reference_type, :string
  end
end
