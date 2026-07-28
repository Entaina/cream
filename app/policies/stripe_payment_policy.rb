class StripePaymentPolicy < WorkspaceRecordPolicy
  def match? = in_workspace?
  def ignore? = in_workspace?
  def unignore? = in_workspace?
end
