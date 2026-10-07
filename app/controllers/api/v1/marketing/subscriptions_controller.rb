module Api
  module V1
    module Marketing
      class SubscriptionsController < BaseController
        requires_feature :marketing_consent

        # Subscriptions (consent per person and type) of the workspace, optionally filtered.
        def index
          authorize :mql, :index?

          if params[:status].present? && EmailSubscription::STATUSES.exclude?(params[:status])
            return render json: {errors: [I18n.t("marketing.subscriptions.errors.invalid_status")]}, status: :unprocessable_entity
          end

          people = policy_scope(current_workspace.people)
          scope = current_workspace.email_subscriptions.where(person_id: people.select(:id))
            .includes(:person, :subscription_type)
          scope = scope.where(subscription_type_id: params[:subscription_type_id]) if params[:subscription_type_id].present?
          scope = scope.where(status: params[:status]) if params[:status].present?
          scope = scope.where(person_id: params[:person_id]) if params[:person_id].present?

          subscriptions = scope.order(updated_at: :desc, id: :desc).limit(list_limit)
          render json: subscriptions.map { |subscription| ::Marketing::ApiPresenter.subscription_listing_json(subscription) }
        end
      end
    end
  end
end
