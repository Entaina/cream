class CreateLeadForms < ActiveRecord::Migration[8.0]
  def change
    create_table :lead_forms do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :pipeline, null: false, foreign_key: true
      t.references :responsible, null: false, foreign_key: { to_table: :users }
      t.references :email_template, null: false, foreign_key: true
      t.string :name, null: false
      t.string :slug, null: false
      t.string :template_key, null: false
      t.boolean :collects_company, null: false, default: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :lead_forms, :slug, unique: true

    create_table :lead_submissions do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :lead_form, null: false, foreign_key: true
      t.references :deal, null: false, foreign_key: true, index: { unique: true }
      t.references :person, null: false, foreign_key: true
      t.jsonb :data, null: false, default: {}
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end
  end
end
