class EditionPolicy < WorkspaceRecordPolicy
  include SettingsManagedPolicy

  # Salespeople add editions on the fly while attaching products to a deal.
  def create? = member? && record.workspace_id.in?([nil, workspace.id])
end
