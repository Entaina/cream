class SalesDirectorBriefingJob < ApplicationJob
  queue_as :default

  def perform(workspace_id = nil)
    if workspace_id
      generate_for(Workspace.find(workspace_id))
    else
      Workspace.sales_director_enabled.find_each { |workspace| generate_for(workspace) }
    end
  end

  private

  def generate_for(workspace)
    Ai::SalesDirector.new(workspace: workspace).call
    workspace.memberships.where(sales_director_briefing_enabled: true).includes(:user).find_each do |membership|
      generate_personal_for(workspace, membership.user)
    end
  rescue => e
    Rails.logger.error("[SalesDirectorBriefingJob] workspace=#{workspace.id}: #{e.class}: #{e.message}")
  end

  def generate_personal_for(workspace, user)
    Ai::PersonalSalesDirector.new(workspace: workspace, user: user).call
  rescue => e
    Rails.logger.error("[SalesDirectorBriefingJob] workspace=#{workspace.id} user=#{user.id}: #{e.class}: #{e.message}")
  end
end
