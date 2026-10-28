class DashboardController < ApplicationController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped
  after_action :verify_authorized, only: :show

  def show
    authorize current_workspace, :dashboard?
    deals_scope = policy_scope(current_workspace.deals)
    deals_scope = deals_scope.where(pipeline_id: current_pipeline.id) if current_pipeline
    @people_count = current_workspace.people.count
    @companies_count = current_workspace.companies.count
    @open_deals = deals_scope.open_deals
    @open_deals_value = @open_deals.sum(:value)
    @won_deals_value = deals_scope.won.sum(:value)
    @pending_tasks = current_workspace.tasks.pending
      .where(assignee: current_user)
      .due_order.includes(:taskable, :assignee).limit(8)
    @recent_activities = policy_scope(current_workspace.activities).includes(:user, :subject).recent_first.limit(15)
    @pipelines = current_workspace.pipelines.ordered
    @pipeline = current_pipeline
    stages = if current_pipeline
      current_pipeline.pipeline_stages.ordered.to_a
    else
      current_workspace.pipeline_stages.ordered_across_pipelines.to_a
    end
    @stages = show_closed? ? stages : stages.reject(&:closed?)
    @deals_by_stage = deals_scope.group(:pipeline_stage_id).count
    @all_pipelines_chart = current_pipeline.nil?
    if @all_pipelines_chart
      @stage_chart_groups = helpers.stage_chart_groups(@stages, @deals_by_stage)
      @stage_chart_max = [@stage_chart_groups.map { |group| group[:total] }.max || 0, 1].max
    end
    if current_membership&.sales_director_briefing_visible?
      @sales_briefing = current_workspace.sales_briefings.team.find_by(briefing_date: Date.current)
      @personal_briefing = current_workspace.sales_briefings.personal_for(current_user).find_by(briefing_date: Date.current)
      @briefing_exists_today = @sales_briefing.present? || @personal_briefing.present?
      @can_regenerate_sales_briefing = @briefing_exists_today && current_membership.can_regenerate_sales_briefing?
      @sales_briefing_regenerations_remaining = current_membership.sales_briefing_regenerations_remaining
    end
  end
end
