class AddProductToLeadForms < ActiveRecord::Migration[8.0]
  def change
    add_reference :lead_forms, :product, null: true, foreign_key: true
  end
end
