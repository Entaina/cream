class LeadFormTemplatePolicy < WorkspaceRecordPolicy
  def index? = admin?
  def create? = admin?
  def update? = admin?
  def destroy? = admin?
  def preview? = admin?
end
