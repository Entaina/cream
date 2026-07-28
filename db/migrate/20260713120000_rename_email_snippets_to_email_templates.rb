class RenameEmailSnippetsToEmailTemplates < ActiveRecord::Migration[8.0]
  INDEX_RENAMES = {
    "index_email_snippets_on_user_id" => "index_email_templates_on_user_id",
    "index_email_snippets_on_workspace_id" => "index_email_templates_on_workspace_id",
    "index_email_snippets_on_workspace_id_and_key" => "index_email_templates_on_workspace_id_and_key"
  }.freeze

  def change
    rename_table :email_snippets, :email_templates

    INDEX_RENAMES.each do |old_name, new_name|
      next unless index_name_exists?(:email_templates, old_name)

      rename_index :email_templates, old_name, new_name
    end
  end
end
