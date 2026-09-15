class CreateStageTriggerRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :stage_trigger_runs do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :stage_trigger, null: false, foreign_key: true
      t.references :deal, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.jsonb :transcript, null: false, default: []
      t.jsonb :ui_actions, null: false, default: []
      t.string :panel_title
      t.text :panel_markdown
      t.text :error
      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps
    end
    add_index :stage_trigger_runs, [:deal_id, :created_at]
  end
end
