class InvitationPolicy < ApplicationPolicy
  def create? = admin?
  def destroy? = admin? && record.workspace_id == workspace.id
  def resend? = destroy?

  class Scope < Scope
    def resolve
      return scope.none unless member?

      scope.where(workspace: workspace)
    end
  end
end
