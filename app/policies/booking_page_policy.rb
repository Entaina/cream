class BookingPagePolicy < WorkspaceRecordPolicy
  def calendars? = member?

  def update?
    in_workspace? && record.host_id == user.id
  end

  def destroy?
    update?
  end
end
