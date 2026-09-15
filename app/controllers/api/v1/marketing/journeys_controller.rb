module Api
  module V1
    module Marketing
      class JourneysController < BaseController
        requires_feature :journeys

        def index
          authorize Journey.new(workspace: current_workspace), :index?
          journeys = policy_scope(current_workspace.journeys).ordered.limit(list_limit)
          render json: journeys.map { |journey| ::Marketing::ApiPresenter.journey_json(journey) }
        end

        def show
          journey = policy_scope(current_workspace.journeys).find(params[:id])
          authorize journey
          render json: ::Marketing::ApiPresenter.journey_json(journey, detail: true)
        end

        def enroll
          journey = policy_scope(current_workspace.journeys).find(params[:id])
          authorize journey, :update?
          person = policy_scope(current_workspace.people).find(enroll_params[:person_id])

          outcome = ::Marketing::JourneyTrigger.enroll!(journey: journey, person: person)
          render json: {outcome: outcome.to_s}
        end

        private

        def enroll_params
          params.require(:enrollment).permit(:person_id)
        end
      end
    end
  end
end
