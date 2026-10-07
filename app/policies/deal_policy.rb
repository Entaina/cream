class DealPolicy < WorkspaceRecordPolicy
  def board? = index?
  def move? = update?
  def show? = in_workspace? && can_view_deal?
  def update? = in_workspace? && can_edit_deal?
  def destroy? = in_workspace? && can_edit_deal?

  def manage_collaborators?
    in_workspace? && (admin? || context.sales_director? || record.owner_id == user.id)
  end

  private

  def can_view_deal?
    return true if admin? || context.sales_director?
    return record.owner_id == user.id if context.ai_salesperson?
    return true if workspace.salespeople_can_view_all_deals? || workspace.salespeople_can_edit_all_deals?

    record.owner_id == user.id || record.deal_accesses.exists?(user_id: user.id)
  end

  def can_edit_deal?
    return true if admin? || context.sales_director?
    return record.owner_id == user.id if context.ai_salesperson?
    return true if workspace.salespeople_can_edit_all_deals?

    record.owner_id == user.id || record.deal_accesses.exists?(user_id: user.id)
  end

  class Scope < Scope
    def resolve
      return scope.none unless member?

      base = scope.where(workspace: workspace)
      return base if context.admin? || context.sales_director?
      return base.where(owner_id: user.id) if context.ai_salesperson?
      return base if workspace.salespeople_can_view_all_deals? || workspace.salespeople_can_edit_all_deals?

      base.where(owner_id: user.id)
        .or(base.where(id: DealAccess.where(user_id: user).select(:deal_id)))
    end
  end
end
