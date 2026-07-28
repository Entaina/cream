class SavedViewPolicy < ApplicationPolicy
  def create? = member?

  def update?
    return false unless member?

    record.user_id == user.id || (record.shared? && admin?)
  end

  def destroy? = update?

  class Scope < Scope
    def resolve
      return scope.none unless member?

      scope.where(workspace: workspace).merge(SavedView.visible_to(user))
    end
  end
end
