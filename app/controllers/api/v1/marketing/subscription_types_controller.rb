module Api
  module V1
    module Marketing
      class SubscriptionTypesController < BaseController
        requires_feature :marketing_consent

        def index
          authorize SubscriptionType.new(workspace: current_workspace), :index?
          SubscriptionType.ensure_defaults!(current_workspace)
          types = policy_scope(current_workspace.subscription_types).active.order(:name)
          render json: types.map { |type| ::Marketing::ApiPresenter.subscription_type_json(type) }
        end
      end
    end
  end
end
