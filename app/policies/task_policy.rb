class TaskPolicy < WorkspaceRecordPolicy
  def toggle? = update?
end
