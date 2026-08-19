module Api
  module V1
    class DealEmailsController < BaseController
      include RequiresFeature
      requires_feature :record_email

      InvalidAttachment = Class.new(StandardError)

      def create
        deal = policy_scope(current_workspace.deals).find(params[:deal_id])
        message = current_workspace.email_messages.new(
          email_params.merge(user: current_user, record: deal, to_address: resolved_to_address(deal))
        )
        authorize message
        attach_files(message)

        if message.save
          deliver_message(message)
          render json: email_json(message), status: :created
        else
          render json: { errors: message.errors.full_messages }, status: :unprocessable_entity
        end
      rescue InvalidAttachment => e
        render json: { errors: [ e.message ] }, status: :unprocessable_entity
      end

      private

      def email_params
        params.require(:email).permit(:to_address, :subject, :body)
      end

      # Attachments arrive as Base64 payloads in the JSON body so the API stays a
      # single content type. Count and per-file size are checked up front (fail
      # fast, before decoding) reusing EmailMessage's limits; the model still runs
      # the authoritative validation (exact byte size and total) on save.
      def attach_files(message)
        raw_attachments = attachment_params
        max_files = EmailMessage::MAX_ATTACHMENTS
        raise InvalidAttachment, "cannot exceed #{max_files} attachments" if raw_attachments.length > max_files

        raw_attachments.each do |raw|
          raise InvalidAttachment, "each attachment must be an object" unless raw.is_a?(ActionController::Parameters) || raw.is_a?(Hash)

          filename = raw[:filename].to_s
          content = raw[:content].to_s
          raise InvalidAttachment, "attachment filename and content are required" if filename.blank? || content.blank?
          raise InvalidAttachment, "attachment #{filename} exceeds #{EmailMessage::MAX_ATTACHMENT_SIZE / 1.megabyte} MB" if oversized?(content)

          options = { io: StringIO.new(decode_base64(content, filename)), filename: filename }
          options[:content_type] = raw[:content_type] if raw[:content_type].present?
          message.attachments.attach(options)
        end
      end

      # Conservative fast-fail: Base64 inflates bytes by 4/3, so a payload longer
      # than that bound is definitely over the limit once decoded.
      def oversized?(content)
        content.bytesize > EmailMessage::MAX_ATTACHMENT_SIZE * 4 / 3 + 4
      end

      def attachment_params
        Array.wrap(params.dig(:email, :attachments))
      end

      def decode_base64(content, filename)
        Base64.strict_decode64(content.gsub(/\s+/, ""))
      rescue ArgumentError
        raise InvalidAttachment, "attachment #{filename} is not valid Base64"
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
          via_gmail: message.route_via_gmail?,
          attachments: message.attachments.map { |file| file.filename.to_s }
        }
      end
    end
  end
end
