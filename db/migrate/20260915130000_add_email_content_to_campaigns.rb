class AddEmailContentToCampaigns < ActiveRecord::Migration[8.0]
  def change
    change_table :campaigns, bulk: true do |t|
      t.references :email_template, foreign_key: {on_delete: :nullify}
      t.references :email_layout, foreign_key: {on_delete: :nullify}
      t.string :email_subject
      t.text :email_body
      t.string :email_body_editor, null: false, default: "quill"
    end

    change_column_null :campaign_sends, :email_template_id, true
  end
end
