class EmailMessagePolicy < WorkspaceRecordPolicy
  def preview?
    member?
  end

  class Scope < Scope
    def resolve
      return scope.none unless member?

      base = scope.where(workspace: workspace)
      visible_deal_ids = DealPolicy::Scope.new(context, workspace.deals).resolve.select(:id)
      base.where("record_type != 'Deal' OR record_id IN (?)", visible_deal_ids)
    end
  end
end
