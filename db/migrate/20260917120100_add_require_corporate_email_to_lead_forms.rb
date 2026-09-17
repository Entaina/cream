class AddRequireCorporateEmailToLeadForms < ActiveRecord::Migration[8.0]
  def change
    add_column :lead_forms, :require_corporate_email, :boolean, default: false, null: false
  end
end
