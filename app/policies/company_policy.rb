class CompanyPolicy < WorkspaceRecordPolicy
  def destroy?
    admin? && in_workspace?
  end

  # Merging permanently deletes the secondary records.
  def merge? = update? && !context.ai_salesperson?
end
