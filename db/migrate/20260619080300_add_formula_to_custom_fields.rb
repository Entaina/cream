class AddFormulaToCustomFields < ActiveRecord::Migration[8.1]
  def change
    add_column :custom_fields, :formula_expression, :text
  end
end
