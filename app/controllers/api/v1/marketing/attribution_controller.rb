module Api
  module V1
    module Marketing
      class AttributionController < BaseController
        requires_feature :marketing_attribution

        def show
          authorize Campaign.new(workspace: current_workspace), :index?

          report = ::Marketing::AttributionReport.new(
            workspace: current_workspace,
            utm_source: params[:utm_source],
            utm_medium: params[:utm_medium],
            utm_campaign: params[:utm_campaign],
            date_range: params[:date_range].presence || "month"
          )
          render json: ::Marketing::ApiPresenter.attribution_rows(report)
        end
      end
    end
  end
end
