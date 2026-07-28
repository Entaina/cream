class CreateStageFieldFormats < ActiveRecord::Migration[8.0]
  def change
    create_table :stage_field_formats do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :pipeline_stage, null: false, foreign_key: true
      t.string :field, null: false
      t.string :operator, null: false, default: "eq"
      t.string :compare_value
      t.string :display_text, null: false
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end
    add_index :stage_field_formats, [ :pipeline_stage_id, :field ]
  end
end
