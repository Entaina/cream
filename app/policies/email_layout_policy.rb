class EmailLayoutPolicy < WorkspaceRecordPolicy
  def preview?
    member?
  end
end
