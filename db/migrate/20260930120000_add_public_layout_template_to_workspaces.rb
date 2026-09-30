class AddPublicLayoutTemplateToWorkspaces < ActiveRecord::Migration[8.1]
  def change
    add_reference :workspaces, :public_layout_template,
      foreign_key: {to_table: :lead_form_templates, on_delete: :nullify},
      null: true
  end
end
