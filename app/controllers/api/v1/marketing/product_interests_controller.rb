module Api
  module V1
    module Marketing
      class ProductInterestsController < BaseController
        requires_feature :mql_pool

        def index
          person = policy_scope(current_workspace.people).find(params[:person_id])
          authorize person, :show?

          scope = person.product_interests.includes(:product).ordered
          scope = scope.where(status: params[:status]) if params[:status].present?
          render json: scope.map { |interest| ::Marketing::ApiPresenter.product_interest_json(interest) }
        end

        def create
          person = policy_scope(current_workspace.people).find(params[:person_id])
          product = policy_scope(current_workspace.products).find(interest_params[:product_id])

          interest = person.product_interests.build(
            workspace: current_workspace,
            product: product,
            description: interest_params[:description],
            recorded_by: current_user,
            source_kind: "manual",
            occurred_at: Time.current,
            status: "pending"
          )
          authorize interest, :create?, policy_class: ::Marketing::ProductInterestPolicy

          if interest.save
            ::Marketing::SegmentWatcher.sync_person!(person)
            render json: ::Marketing::ApiPresenter.product_interest_json(interest), status: :created
          else
            render json: {errors: interest.errors.full_messages}, status: :unprocessable_entity
          end
        end

        private

        def interest_params
          params.require(:product_interest).permit(:product_id, :description)
        end
      end
    end
  end
end
