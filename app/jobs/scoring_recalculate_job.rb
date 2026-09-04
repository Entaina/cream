class ScoringRecalculateJob < ApplicationJob
  queue_as :default

  def perform(workspace_id = nil)
    scope = workspace_id ? Workspace.where(id: workspace_id) : Workspace.all
    scope.find_each do |workspace|
      Marketing::ScoringEngine.recalculate!(workspace)
    end
  end
end
