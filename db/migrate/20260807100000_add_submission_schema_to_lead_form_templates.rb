class AddSubmissionSchemaToLeadFormTemplates < ActiveRecord::Migration[8.1]
  def change
    add_column :lead_form_templates, :submission_schema, :jsonb, null: false, default: {}
  end
end
