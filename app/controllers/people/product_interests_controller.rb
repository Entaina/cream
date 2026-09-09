module People
  class ProductInterestsController < ApplicationController
    include RequiresFeature
    requires_feature :mql_pool

    before_action :set_person
    before_action :set_interest, only: :dismiss

    def create
      @interest = @person.product_interests.build(interest_params.merge(
        workspace: current_workspace,
        recorded_by: current_user,
        source_kind: "manual",
        occurred_at: Time.current
      ))
      authorize @interest, policy_class: Marketing::ProductInterestPolicy

      if @interest.save
        Marketing::SegmentWatcher.sync_person!(@person)
        redirect_to @person, notice: "Interés registrado."
      else
        redirect_to @person, alert: @interest.errors.full_messages.to_sentence
      end
    end

    def dismiss
      authorize @interest, :dismiss?, policy_class: Marketing::ProductInterestPolicy
      @interest.dismiss!(reason: params.require(:dismissal_reason), actor: current_user)
      redirect_to @person, notice: "Interés descartado."
    end

    private

    def set_person
      @person = policy_scope(current_workspace.people).find(params[:person_id])
    end

    def set_interest
      @interest = @person.product_interests.find(params[:id])
    end

    def interest_params
      params.require(:product_interest).permit(:product_id, :description)
    end
  end
end
