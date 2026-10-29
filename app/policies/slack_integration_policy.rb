# The incoming webhook URL is a secret, so only admins can list integrations.
class SlackIntegrationPolicy < WorkspaceRecordPolicy
  def index? = admin?
  def show? = admin? && in_workspace?
  def create? = admin?
  def update? = admin?
  def destroy? = admin?
end
