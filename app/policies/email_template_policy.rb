class EmailTemplatePolicy < WorkspaceRecordPolicy
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
