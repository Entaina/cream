module Api
  module V1
    module Marketing
      class CampaignsController < BaseController
        requires_feature :marketing_campaigns

        def index
          authorize Campaign.new(workspace: current_workspace), :index?
          campaigns = policy_scope(current_workspace.campaigns).ordered.limit(list_limit)
          render json: campaigns.map { |campaign| ::Marketing::ApiPresenter.campaign_json(campaign) }
        end

        def show
          campaign = policy_scope(current_workspace.campaigns).find(params[:id])
          authorize campaign
          render json: ::Marketing::ApiPresenter.campaign_json(campaign, detail: true)
        end
      end
    end
  end
end
