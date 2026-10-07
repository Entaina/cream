module Api
  module V1
    class PersonAttachmentsController < BaseController
      requires_feature :attachments

      # Accepts a Base64 object ({attachment: {filename, content, content_type?, name?}}) in a JSON
      # body, or a file upload (multipart/form-data: attachment[file], attachment[name]?).
      def create
        person = policy_scope(current_workspace.people).find(params[:person_id])
        attachment = Api::RecordAttachmentBuilder.new(workspace: current_workspace, user: current_user, record: person)
          .build(raw_file, name: attachment_params[:name])
        authorize attachment

        if attachment.save
          render json: Api::RecordAttachmentBuilder.json(attachment), status: :created
        else
          render json: {errors: attachment.errors.full_messages}, status: :unprocessable_entity
        end
      rescue Api::RecordAttachmentBuilder::InvalidAttachment => e
        render json: {errors: [e.message]}, status: :unprocessable_entity
      end

      private

      def attachment_params
        params.require(:attachment).permit(:file, :filename, :content, :content_type, :name)
      end

      def raw_file
        attachment_params[:file].presence || attachment_params.slice(:filename, :content, :content_type)
      end
    end
  end
end
