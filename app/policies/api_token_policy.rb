class ApiTokenPolicy < ApplicationPolicy
  def index? = member?
  def create? = member?
  def destroy? = member? && record.user_id == user.id

  class Scope < Scope
    def resolve
      return scope.none unless member?

      scope.where(user: user, workspace: workspace)
    end
  end
end
