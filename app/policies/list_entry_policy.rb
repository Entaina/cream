class ListEntryPolicy < ApplicationPolicy
  def create? = member? && record.list.workspace_id == workspace.id
  def destroy? = member? && record.list.workspace_id == workspace.id
end
