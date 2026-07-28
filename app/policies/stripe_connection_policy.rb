# The API key is a workspace-wide secret: mutations are admin-only (like
# webhooks), unlike Gmail where each user owns their personal connection.
class StripeConnectionPolicy < WorkspaceRecordPolicy
  def create? = admin? && (record.workspace.nil? || record.workspace_id == workspace.id)
  def update? = admin? && in_workspace?
  def destroy? = admin? && in_workspace?
  def sync? = admin? && in_workspace?
end
