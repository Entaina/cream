class PersonPolicy < WorkspaceRecordPolicy
  # Merging permanently deletes the secondary records.
  def merge? = update? && !context.ai_salesperson?
end
