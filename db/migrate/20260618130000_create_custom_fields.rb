class CreateCustomFields < ActiveRecord::Migration[8.1]
  def change
    create_table :custom_fields do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :record_type, null: false
      t.string :name, null: false
      t.string :key, null: false
      t.string :field_type, null: false
      t.jsonb :options, null: false, default: []
      t.integer :position, null: false, default: 0
      t.boolean :required, null: false, default: false

      t.timestamps
    end

    add_index :custom_fields, %i[workspace_id record_type key], unique: true
    add_index :custom_fields, %i[workspace_id record_type position]

    create_table :custom_field_values do |t|
      t.references :custom_field, null: false, foreign_key: true
      t.references :workspace, null: false, foreign_key: true
      t.references :record, polymorphic: true, null: false
      t.jsonb :value

      t.timestamps
    end

    add_index :custom_field_values, %i[custom_field_id record_type record_id],
      unique: true, name: "index_custom_field_values_on_field_and_record"
    add_index :custom_field_values, %i[record_type record_id]
  end
end
