# Webhook URLs can embed credentials, so only admins can list webhooks.
class WebhookPolicy < WorkspaceRecordPolicy
  def index? = admin?
  def show? = admin? && in_workspace?
  def create? = admin?
  def update? = admin?
  def destroy? = admin?
end
