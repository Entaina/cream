class SalesBriefingsController < ApplicationController
  include RequiresFeature

  requires_feature :sales_director

  def create
    authorize current_workspace, :dashboard?

    unless Ai::Configuration.configured?
      redirect_to root_path, alert: t("flashes.sales_briefings.ai_not_configured")
      return
    end

    unless current_workspace.sales_director_enabled?
      redirect_to root_path, alert: t("flashes.sales_briefings.not_enabled")
      return
    end

    unless current_membership.sales_director_briefing_enabled?
      redirect_to root_path, alert: t("flashes.sales_briefings.disabled_for_user")
      return
    end

    briefing_exists = sales_briefing_exists_today?

    if briefing_exists
      unless current_membership.can_regenerate_sales_briefing?
        redirect_to root_path, alert: t("flashes.sales_briefings.daily_limit")
        return
      end

      current_membership.record_sales_briefing_regeneration!
    end

    SalesDirectorBriefingJob.perform_later(current_workspace.id)
    notice = briefing_exists ? t("flashes.sales_briefings.regenerating") : t("flashes.sales_briefings.generating")
    redirect_to root_path, notice: notice
  end

  private

  def sales_briefing_exists_today?
    current_workspace.sales_briefings.team.exists?(briefing_date: Date.current) ||
      current_workspace.sales_briefings.personal_for(current_user).exists?(briefing_date: Date.current)
  end
end
