class AddHiddenFieldKeysToLeadForms < ActiveRecord::Migration[8.0]
  def change
    add_column :lead_forms, :hidden_field_keys, :jsonb, null: false, default: []
  end
end
