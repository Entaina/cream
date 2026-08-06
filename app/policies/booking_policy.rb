class BookingPolicy < WorkspaceRecordPolicy
  def cancel? = member?
end
