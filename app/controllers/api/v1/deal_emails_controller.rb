module Api
  module V1
    class DealEmailsController < BaseController
      include RequiresFeature
      requires_feature :record_email

      def create
        deal = policy_scope(current_workspace.deals).find(params[:deal_id])
        message = current_workspace.email_messages.new(
          email_params.merge(user: current_user, record: deal, to_address: resolved_to_address(deal))
        )
        authorize message

        if message.save
          deliver_message(message)
          render json: email_json(message), status: :created
        else
          render json: { errors: message.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def email_params
        params.require(:email).permit(:to_address, :subject, :body)
      end

      def resolved_to_address(deal)
        email_params[:to_address].presence || deal.contacts.first&.email
      end

      def deliver_message(message)
        if message.route_via_gmail?
          SendViaGmailJob.perform_later(message.id)
        else
          RecordMailer.tracked_email(message: message).deliver_later
          message.track_sent!
        end
      end

      def email_json(message)
        {
          id: message.id,
          to_address: message.to_address,
          subject: message.subject,
          status: message.status,
          via_gmail: message.route_via_gmail?
        }
      end
    end
  end
end
