class SalesBriefingsController < ApplicationController
  include RequiresFeature

  requires_feature :sales_director

  def create
    authorize current_workspace, :dashboard?

    unless Ai::Configuration.configured?
      redirect_to root_path, alert: "AI is not configured. Set CREAM_AI_API_KEY."
      return
    end

    unless current_workspace.sales_director_enabled?
      redirect_to root_path, alert: "El director de ventas no está habilitado para este workspace."
      return
    end

    unless current_membership.sales_director_briefing_enabled?
      redirect_to root_path, alert: "Has desactivado el briefing del director de ventas en tu perfil."
      return
    end

    briefing_exists = sales_briefing_exists_today?

    if briefing_exists
      unless current_membership.can_regenerate_sales_briefing?
        redirect_to root_path, alert: "Has alcanzado el límite de 5 regeneraciones diarias."
        return
      end

      current_membership.record_sales_briefing_regeneration!
    end

    SalesDirectorBriefingJob.perform_later(current_workspace.id)
    notice = briefing_exists ? "El briefing se está regenerando. Actualiza en un momento." : "Sales briefing is being generated. Refresh in a moment."
    redirect_to root_path, notice: notice
  end

  private

  def sales_briefing_exists_today?
    current_workspace.sales_briefings.team.exists?(briefing_date: Date.current) ||
      current_workspace.sales_briefings.personal_for(current_user).exists?(briefing_date: Date.current)
  end
end
