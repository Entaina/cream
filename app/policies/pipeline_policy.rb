class PipelinePolicy < WorkspaceRecordPolicy
  def reorder_stages? = update?
end
