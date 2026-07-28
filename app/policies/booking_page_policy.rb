class BookingPagePolicy < WorkspaceRecordPolicy
  def calendars? = member?
end
