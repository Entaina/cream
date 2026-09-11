module Api
  module V1
    module Marketing
      class MqlsController < BaseController
        requires_feature :mql_pool

        def index
          authorize :mql, :index?

          filters = ::Marketing::ApiPresenter.mql_filters_from_params(params)
          base = ::Marketing::MqlEligibility.scope(
            workspace: current_workspace,
            subscription_type_id: filters["subscription_type_id"]
          )
          people = ::Marketing::FilterResolver.new(
            workspace: current_workspace,
            record_type: "Person",
            filters: filters,
            deal_scope: policy_scope(current_workspace.deals)
          ).resolve(
            base.includes(:company, :product_interests, email_subscriptions: :subscription_type)
          )

          people = people.order(lead_score: :desc, updated_at: :desc).limit(list_limit)
          render json: people.map { |person| ::Marketing::ApiPresenter.mql_json(person) }
        end
      end
    end
  end
end
