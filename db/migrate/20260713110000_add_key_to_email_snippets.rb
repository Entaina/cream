class AddKeyToEmailSnippets < ActiveRecord::Migration[8.0]
  def change
    add_column :email_snippets, :key, :string
    add_index :email_snippets, %i[workspace_id key], unique: true, where: "key IS NOT NULL"
  end
end
