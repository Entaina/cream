class BookingPolicy < WorkspaceRecordPolicy
  def cancel?
    in_workspace? && host?
  end

  class Scope < Scope
    def resolve
      return scope.none unless member?

      scope.where(workspace: workspace, booking_page_id: host_page_ids)
    end

    private

    def host_page_ids
      BookingPage.where(workspace: workspace, host_id: user.id).select(:id)
    end
  end

  private

  def host?
    record.booking_page.host_id == user.id
  end
end
