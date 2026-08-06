class MakeLeadFormEmailTemplateOptional < ActiveRecord::Migration[8.0]
  def change
    change_column_null :lead_forms, :email_template_id, true
  end
end
