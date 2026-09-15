class AddTasksDueIndex < ActiveRecord::Migration[8.0]
  def change
    add_index :tasks, [:workspace_id, :assignee_id, :completed_at, :due_on],
      name: "index_tasks_on_ws_assignee_completed_due"
  end
end
