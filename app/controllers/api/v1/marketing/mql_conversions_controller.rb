module Api
  module V1
    module Marketing
      class MqlConversionsController < BaseController
        requires_feature :mql_pool

        def create
          interest = ::Marketing::ProductInterest.where(workspace: current_workspace).find(conversion_params[:product_interest_id])
          authorize interest, :convert?, policy_class: ::Marketing::ProductInterestPolicy

          result = ::Marketing::MqlToSqlConverter.call(
            interest: interest,
            actor: current_user,
            attributes: conversion_params.except(:product_interest_id)
          )

          payload = {
            status: result.status,
            message: result.message,
            interest: ::Marketing::ApiPresenter.product_interest_json(result.interest)
          }
          payload[:deal] = ::Marketing::ApiPresenter.deal_json(result.deal) if result.deal

          status = result.status.in?(%w[created linked already_converted]) ? :ok : :unprocessable_entity
          render json: payload, status: status
        end

        private

        def conversion_params
          params.require(:conversion).permit(
            :product_interest_id, :pipeline_id, :task_title, :task_due_on,
            :name, :owner_id, :task_assignee_id, :deal_id
          )
        end
      end
    end
  end
end
