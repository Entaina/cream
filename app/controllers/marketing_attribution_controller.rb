class MarketingAttributionController < ApplicationController
  include RequiresFeature
  requires_feature :marketing_attribution

  def show
    authorize Campaign, :index?
    @rows = Marketing::AttributionReport.new(
      workspace: current_workspace,
      utm_source: params[:utm_source],
      utm_medium: params[:utm_medium],
      utm_campaign: params[:utm_campaign],
      date_range: params[:date_range].presence || "month"
    ).rows
  end
end
