class WorkspacePolicy < ApplicationPolicy
  def show? = user.present? && Membership.exists?(user: user, workspace: record)
  def update? = admin? && show?
  def search? = member?
  def dashboard? = member?
  def import? = member?
  def export? = member?
  def mail_merge? = member?

  class Scope < Scope
    def resolve
      return scope.none unless member?

      scope.where(id: workspace.id)
    end
  end
end
