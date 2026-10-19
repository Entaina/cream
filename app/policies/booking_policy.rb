class BookingPolicy < WorkspaceRecordPolicy
  def cancel?
    in_workspace? && host?
  end

  class Scope < Scope
    def resolve
      return scope.none unless member?

      scope.where(workspace: workspace, booking_page_id: participant_page_ids)
    end

    private

    def participant_page_ids
      BookingPage.where(workspace: workspace, host_id: user.id)
        .or(BookingPage.where(workspace: workspace, id: BookingPageMember.where(user_id: user.id).select(:booking_page_id)))
        .select(:id)
    end
  end

  private

  def host?
    record.booking_page.participant?(user)
  end
end
