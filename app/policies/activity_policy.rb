class ActivityPolicy < WorkspaceRecordPolicy
  class Scope < Scope
    def resolve
      return scope.none unless member?

      base = scope.where(workspace: workspace)
      visible_deal_ids = DealPolicy::Scope.new(context, workspace.deals).resolve.select(:id)
      base.where(
        "subject_type != 'Deal' OR subject_id IN (?)",
        visible_deal_ids
      )
    end
  end
end
