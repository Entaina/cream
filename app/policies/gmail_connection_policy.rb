class GmailConnectionPolicy < WorkspaceRecordPolicy
  def create? = member? && record.user_id == user.id
  def update? = record.user_id == user.id
  def sync? = update?
  def destroy? = record.user_id == user.id
end
