class BeehiivPublicationPolicy < WorkspaceRecordPolicy
  def create? = admin? && connection_in_workspace?
  def update? = admin? && in_workspace?
  def destroy? = admin? && in_workspace?

  private

  def connection_in_workspace?
    record.beehiiv_connection&.workspace_id == workspace.id
  end
end
