class AddFirstTaskToLeadForms < ActiveRecord::Migration[8.0]
  def change
    add_column :lead_forms, :first_task_title, :string, null: false, default: "Contactar lead"
    add_column :lead_forms, :first_task_due_days, :integer, null: false, default: 1
  end
end
