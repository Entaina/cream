class PipelinePolicy < WorkspaceRecordPolicy
  include SettingsManagedPolicy

  def reorder_stages? = update?
end
