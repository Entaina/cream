# Workspace-wide ESP credentials: mutations are admin-only (like Stripe).
class MailjetConnectionPolicy < WorkspaceRecordPolicy
  def create? = admin? && (record.workspace.nil? || record.workspace_id == workspace.id)
  def update? = admin? && in_workspace?
  def destroy? = admin? && in_workspace?
end
