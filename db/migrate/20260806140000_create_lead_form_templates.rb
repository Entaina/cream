class CreateLeadFormTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :lead_form_templates do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :path, null: false
      t.boolean :partial, null: false, default: false
      t.text :body, null: false

      t.timestamps
    end

    add_index :lead_form_templates, [:workspace_id, :path], unique: true
  end
end
