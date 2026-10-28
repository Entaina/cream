class EmailTemplatePolicy < WorkspaceRecordPolicy
  def show?
    in_workspace? && (record.shared? || record.user_id == user.id || admin?)
  end

  def preview?
    member?
  end

  def update?
    in_workspace? && (record.user_id == user.id || admin?)
  end

  def destroy?
    update?
  end
end
