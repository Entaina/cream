class DealPolicy < WorkspaceRecordPolicy
  def board? = index?
  def move? = update?
  def show? = in_workspace? && can_access_deal?
  def update? = in_workspace? && can_access_deal?
  def destroy? = in_workspace? && can_access_deal?

  def manage_collaborators?
    in_workspace? && (admin? || context.sales_director? || record.owner_id == user.id)
  end

  private

  def can_access_deal?
    return true if admin? || context.sales_director?

    record.owner_id == user.id || record.deal_accesses.exists?(user_id: user.id)
  end

  class Scope < Scope
    def resolve
      return scope.none unless member?

      base = scope.where(workspace: workspace)
      return base if context.admin? || context.sales_director?

      base.where(owner_id: user.id)
          .or(base.where(id: DealAccess.where(user_id: user).select(:deal_id)))
    end
  end
end
