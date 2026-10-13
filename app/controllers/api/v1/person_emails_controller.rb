module Api
  module V1
    class PersonEmailsController < BaseController
      include RequiresFeature

      requires_feature :record_email

      def create
        person = policy_scope(current_workspace.people).find(params[:person_id])
        creator = build_creator(person)
        message = creator.build
        authorize message

        if message.save
          creator.deliver(message)
          render json: Api::DealEmailCreator.json(message), status: :created
        else
          render json: {errors: message.errors.full_messages}, status: :unprocessable_entity
        end
      rescue Api::DealEmailCreator::InvalidAttachment => e
        render json: {errors: [e.message]}, status: :unprocessable_entity
      end

      private

      def build_creator(person)
        Api::DealEmailCreator.new(
          workspace: current_workspace,
          user: current_user,
          record: person,
          email_attrs: email_params.to_h,
          attachments: attachment_params
        )
      end

      def email_params
        params.require(:email).permit(:to_address, :subject, :body)
      end

      def attachment_params
        Api::DealEmailCreator.parse_attachments(params.dig(:email, :attachments))
      end
    end
  end
end
