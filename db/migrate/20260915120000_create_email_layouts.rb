class CreateEmailLayouts < ActiveRecord::Migration[8.0]
  def change
    create_table :email_layouts do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :name, null: false
      t.text :body, null: false

      t.timestamps
    end

    add_reference :email_templates, :email_layout, foreign_key: {on_delete: :nullify}
    add_column :email_templates, :body_editor, :string, null: false, default: "quill"
  end
end
