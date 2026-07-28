class WorkspaceRecordPolicy < ApplicationPolicy
  def index? = member?
  def show? = in_workspace?
  def create? = member? && (record.workspace.nil? || record.workspace_id == workspace.id)
  def update? = in_workspace?
  def destroy? = in_workspace?

  class Scope < Scope
    def resolve
      return scope.none unless member?

      scope.where(workspace: workspace)
    end
  end
end
