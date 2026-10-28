class ReportPolicy < WorkspaceRecordPolicy
  def update?
    in_workspace? && (record.user_id == user.id || admin?)
  end

  def destroy?
    update?
  end
end
