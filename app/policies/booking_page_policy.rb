class BookingPagePolicy < WorkspaceRecordPolicy
  def calendars? = member?

  def update?
    in_workspace? && record.participant?(user)
  end

  def destroy?
    update?
  end
end
