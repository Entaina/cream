class EmailMessagePolicy < WorkspaceRecordPolicy
  def preview?
    member?
  end
end
