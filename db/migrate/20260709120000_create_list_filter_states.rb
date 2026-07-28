class CreateListFilterStates < ActiveRecord::Migration[8.1]
  def change
    create_table :list_filter_states do |t|
      t.references :session, null: false, foreign_key: true
      t.references :workspace, null: false, foreign_key: true
      t.string :key, null: false
      t.jsonb :params, null: false, default: {}
      t.timestamps
    end

    add_index :list_filter_states, %i[session_id workspace_id key], unique: true
  end
end
