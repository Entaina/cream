module Api
  module V1
    class GmailThreadsController < BaseController
      requires_feature :gmail_addon

      def status
        authorize Deal, :index?
        result = linker.status(
          gmail_thread_id: thread_status_params[:gmail_thread_id],
          rfc822_message_ids: Array(thread_status_params[:rfc822_message_ids]),
          participant_emails: Array(thread_status_params[:participant_emails])
        )
        render json: result
      end

      def link
        deal = authorize_and_link!
        render json: deal, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: {errors: e.record.errors.full_messages}, status: :unprocessable_entity
      rescue GmailThreadLinker::CompanyRequired => e
        render json: {errors: [e.message], company_name: e.name, domain: e.domain}, status: :unprocessable_entity
      rescue GmailThreadLinker::ContactOutsideCompany => e
        render json: {errors: [e.message], email: e.email, company_name: e.company_name}, status: :unprocessable_entity
      rescue ActiveRecord::RecordNotFound
        head :not_found
      end

      private

      def authorize_and_link!
        if link_params[:deal_id].present?
          deal = policy_scope(current_workspace.deals).find(link_params[:deal_id])
          authorize deal, :update?
        else
          authorize current_workspace.deals.new, :create?
        end

        linker.link(
          deal_id: link_params[:deal_id],
          new_deal: link_params[:new_deal]&.to_unsafe_h,
          thread: link_params.require(:thread).to_unsafe_h.deep_symbolize_keys
        )
      end

      def linker
        @linker ||= GmailThreadLinker.new(workspace: current_workspace, user: current_user)
      end

      def thread_status_params
        params.permit(:gmail_thread_id, rfc822_message_ids: [], participant_emails: [])
      end

      def link_params
        params.permit(:deal_id, new_deal: [
          :name, :pipeline_stage_id, :company_id, :company_name, :create_company,
          :contact_name, :named_contact_email, {contact_emails: []}
        ], thread: [
          :gmail_thread_id,
          {messages: %i[gmail_message_id rfc822_message_id from to cc subject body sent_at]}
        ])
      end
    end
  end
end
