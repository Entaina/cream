class MarketingAdminPolicy < ApplicationPolicy
  def index? = admin?
  def show? = admin? && in_workspace?
  def create? = admin?
  def update? = admin? && in_workspace?
  def destroy? = admin? && in_workspace?

  class Scope < Scope
    def resolve
      return scope.none unless admin?

      scope.where(workspace: workspace)
    end
  end
end
