class PersonPolicy < WorkspaceRecordPolicy
  def merge? = update?
end
