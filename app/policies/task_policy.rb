# Tasks on a deal follow that deal's visibility and edit rights. The author and the
# assignee always keep their own tasks. Tasks on people, companies or no record stay
# open to every member.
class TaskPolicy < WorkspaceRecordPolicy
  def show? = in_workspace? && (own_task? || deal_allows?(:show?))
  def update? = in_workspace? && (own_task? || deal_allows?(:update?))
  def destroy? = update?
  def toggle? = update?

  private

  def own_task? = record.user_id == user.id || record.assignee_id == user.id

  def deal_allows?(action)
    return true unless record.taskable_type == "Deal"
    return false unless record.taskable

    DealPolicy.new(context, record.taskable).public_send(action)
  end

  class Scope < Scope
    def resolve
      return scope.none unless member?

      base = scope.where(workspace: workspace)
      visible_deal_ids = DealPolicy::Scope.new(context, workspace.deals).resolve.select(:id)
      base.where("tasks.taskable_type IS DISTINCT FROM 'Deal' OR tasks.taskable_id IN (?)", visible_deal_ids)
        .or(base.where(assignee_id: user.id))
        .or(base.where(user_id: user.id))
    end
  end
end
