class PersonRelationshipPolicy < ApplicationPolicy
  def create? = member?

  def destroy? = in_workspace?

  def in_workspace?
    member? && record.from_person&.workspace_id == workspace.id
  end

  class Scope < Scope
    def resolve
      return scope.none unless member?

      scope.joins(:from_person).where(people: {workspace_id: workspace.id})
    end
  end
end
