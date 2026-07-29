class AlertRulePolicy < WorkspaceRecordPolicy
  def create? = admin?
  def update? = admin?
  def destroy? = admin?
end
