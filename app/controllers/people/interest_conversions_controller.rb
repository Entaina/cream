module People
  class InterestConversionsController < ApplicationController
    include RequiresFeature

    requires_feature :mql_pool

    before_action :set_person
    before_action :set_interest

    def new
      authorize @interest, :convert?, policy_class: Marketing::ProductInterestPolicy
      @pipelines = current_workspace.pipelines.ordered.includes(:pipeline_stages)
      @default_pipeline = Pipeline.default_for(current_workspace)
    end

    def create
      authorize @interest, :convert?, policy_class: Marketing::ProductInterestPolicy

      result = Marketing::MqlToSqlConverter.call(
        interest: @interest,
        actor: current_user,
        attributes: conversion_params
      )

      respond_to do |format|
        format.html do
          case result.status
          when "created", "linked", "already_converted"
            redirect_to result.deal, notice: result.message
          when "conflict"
            redirect_to @person, alert: result.message, status: :see_other
          else
            @pipelines = current_workspace.pipelines.ordered.includes(:pipeline_stages)
            @default_pipeline = Pipeline.default_for(current_workspace)
            flash.now[:alert] = result.message
            render :new, status: :unprocessable_entity
          end
        end
      end
    end

    private

    def set_person
      @person = policy_scope(current_workspace.people).find(params[:person_id])
    end

    def set_interest
      @interest = @person.product_interests.find(params[:product_interest_id])
    end

    def conversion_params
      params.require(:conversion).permit(:pipeline_id, :name, :task_title, :task_due_on, :task_assignee_id, :owner_id)
    end
  end
end
