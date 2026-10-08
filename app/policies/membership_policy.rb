class MembershipPolicy < ApplicationPolicy
  def update? = admin? && in_workspace?
  def destroy? = admin? && in_workspace? && record.user_id != user.id

  class Scope < Scope
    def resolve
      return scope.none unless member?

      scope.real_team.where(workspace: workspace).includes(:user)
    end
  end
end
