module Api
  class DealEmailCreator
    InvalidAttachment = Class.new(StandardError)
    RecordEmailDisabled = Class.new(StandardError)

    def initialize(workspace:, user:, deal:, email_attrs:, attachments: [])
      @workspace = workspace
      @user = user
      @deal = deal
      @email_attrs = email_attrs.symbolize_keys
      @attachments = attachments
    end

    def build
      message = @workspace.email_messages.new(
        @email_attrs.except(:attachments).merge(
          user: @user,
          record: @deal,
          to_address: resolved_to_address
        )
      )
      attach_files(message)
      message
    end

    def deliver(message)
      if message.route_via_gmail?
        SendViaGmailJob.perform_later(message.id)
      else
        RecordMailer.tracked_email(message: message).deliver_later
        message.track_sent!
      end
    end

    def self.json(message)
      {
        id: message.id,
        to_address: message.to_address,
        subject: message.subject,
        status: message.status,
        via_gmail: message.route_via_gmail?,
        attachments: message.attachments.map { |file| file.filename.to_s }
      }
    end

    def self.parse_attachments(raw)
      Array.wrap(raw).compact_blank
    end

    private

    def resolved_to_address
      @email_attrs[:to_address].presence || @deal.contacts.first&.email
    end

    # Attachments may be uploaded files (multipart/form-data) or Base64 objects
    # in a JSON body. Count and per-file size are checked up front; the model
    # still runs the authoritative validation (exact byte size and total) on save.
    def attach_files(message)
      files = self.class.parse_attachments(@attachments)
      max_files = EmailMessage::MAX_ATTACHMENTS
      raise InvalidAttachment, "cannot exceed #{max_files} attachments" if files.length > max_files

      files.each do |raw|
        if uploaded_file?(raw)
          attach_uploaded_file(message, raw)
        else
          attach_base64_file(message, raw)
        end
      end
    end

    def uploaded_file?(raw)
      raw.is_a?(ActionDispatch::Http::UploadedFile)
    end

    def attach_uploaded_file(message, file)
      filename = file.original_filename.presence || "attachment"
      raise InvalidAttachment, "attachment #{filename} exceeds #{EmailMessage::MAX_ATTACHMENT_SIZE / 1.megabyte} MB" if file.size > EmailMessage::MAX_ATTACHMENT_SIZE

      file.rewind if file.respond_to?(:rewind)
      options = { io: file.tempfile, filename: filename }
      options[:content_type] = file.content_type if file.content_type.present?
      message.attachments.attach(options)
    end

    def attach_base64_file(message, raw)
      raw = raw.to_unsafe_h if raw.respond_to?(:to_unsafe_h)
      raw = raw.symbolize_keys if raw.is_a?(Hash)
      raise InvalidAttachment, "each attachment must be an object or uploaded file" unless raw.is_a?(Hash)

      filename = raw[:filename].to_s
      content = raw[:content].to_s
      raise InvalidAttachment, "attachment filename and content are required" if filename.blank? || content.blank?
      raise InvalidAttachment, "attachment #{filename} exceeds #{EmailMessage::MAX_ATTACHMENT_SIZE / 1.megabyte} MB" if oversized?(content)

      options = { io: StringIO.new(decode_base64(content, filename)), filename: filename }
      options[:content_type] = raw[:content_type] if raw[:content_type].present?
      message.attachments.attach(options)
    end

    # Conservative fast-fail: Base64 inflates bytes by 4/3, so a payload longer
    # than that bound is definitely over the limit once decoded.
    def oversized?(content)
      content.bytesize > EmailMessage::MAX_ATTACHMENT_SIZE * 4 / 3 + 4
    end

    def decode_base64(content, filename)
      Base64.strict_decode64(content.gsub(/\s+/, ""))
    rescue ArgumentError
      raise InvalidAttachment, "attachment #{filename} is not valid Base64"
    end
  end
end
