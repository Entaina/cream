class CompanyPolicy < WorkspaceRecordPolicy
  def merge? = update?
end
