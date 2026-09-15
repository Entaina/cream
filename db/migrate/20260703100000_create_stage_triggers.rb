class CreateStageTriggers < ActiveRecord::Migration[8.0]
  def change
    create_table :stage_triggers do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :pipeline_stage, null: false, foreign_key: true
      t.string :name, null: false
      t.text :instructions
      t.string :execution_mode, null: false, default: "llm"
      t.string :native_function
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end
    add_index :stage_triggers, [:pipeline_stage_id, :position]
  end
end
