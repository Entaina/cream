class NotePolicy < WorkspaceRecordPolicy
  def update?
    in_workspace? && (admin? || record.user_id == user.id)
  end

  def destroy?
    update?
  end
end
