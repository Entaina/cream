class NotificationPolicy < ApplicationPolicy
  def index? = member?
  def update? = record.user_id == user.id
  def mark_all_read? = member?

  class Scope < Scope
    def resolve
      return scope.none unless member?

      scope.where(user: user, workspace: workspace)
    end
  end
end
