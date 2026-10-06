module Api
  module V1
    class GmailDealContactsController < BaseController
      requires_feature :gmail_addon

      def create
        deal = policy_scope(current_workspace.deals).find(params[:deal_id])
        authorize deal, :update?

        result = linker.add_contacts!(deal: deal, contacts: contact_params)
        render json: result
      rescue ActiveRecord::RecordInvalid => e
        render json: {errors: e.record.errors.full_messages}, status: :unprocessable_entity
      rescue GmailThreadLinker::ContactOutsideCompany => e
        render json: {errors: [e.message], email: e.email, company_name: e.company_name}, status: :unprocessable_entity
      rescue ArgumentError => e
        render json: {errors: [e.message]}, status: :unprocessable_entity
      end

      private

      def linker
        @linker ||= GmailThreadLinker.new(workspace: current_workspace, user: current_user)
      end

      def contact_params
        Array(params[:contacts]).map do |entry|
          entry = ActionController::Parameters.new(entry) unless entry.is_a?(ActionController::Parameters)
          entry.permit(:email, :name).to_h
        end
      end
    end
  end
end
