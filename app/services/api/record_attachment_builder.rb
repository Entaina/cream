module Api
  # Builds a RecordAttachment from an uploaded file (multipart/form-data) or a
  # Base64 object ({filename, content, content_type?, name?}) in a JSON body.
  # The caller authorizes and saves the returned record.
  class RecordAttachmentBuilder
    InvalidAttachment = Class.new(StandardError)

    MAX_FILES = EmailMessage::MAX_ATTACHMENTS
    MAX_FILE_SIZE = EmailMessage::MAX_ATTACHMENT_SIZE

    def self.json(attachment)
      {
        id: attachment.id,
        name: attachment.display_name,
        filename: attachment.file.filename.to_s,
        content_type: attachment.file.content_type,
        byte_size: attachment.file.byte_size,
        created_at: attachment.created_at.iso8601
      }
    end

    # Validates how many files were sent before any of them is built.
    def self.ensure_count!(files)
      return if files.length <= MAX_FILES

      raise InvalidAttachment, "cannot exceed #{MAX_FILES} attachments"
    end

    def initialize(workspace:, user:, record:)
      @workspace = workspace
      @user = user
      @record = record
    end

    def build(raw, name: nil)
      attachment = @record.record_attachments.new(workspace: @workspace, user: @user, name: name.presence)

      if raw.is_a?(ActionDispatch::Http::UploadedFile)
        attach_uploaded_file(attachment, raw)
      else
        attach_base64_file(attachment, raw)
      end
      attachment
    end

    private

    def attach_uploaded_file(attachment, file)
      filename = file.original_filename.presence || "attachment"
      raise InvalidAttachment, too_large(filename) if file.size > MAX_FILE_SIZE

      file.rewind if file.respond_to?(:rewind)
      options = {io: file.tempfile, filename: filename}
      options[:content_type] = file.content_type if file.content_type.present?
      attachment.file.attach(options)
    end

    def attach_base64_file(attachment, raw)
      raw = raw.to_unsafe_h if raw.respond_to?(:to_unsafe_h)
      raw = raw.symbolize_keys if raw.is_a?(Hash)
      raise InvalidAttachment, "each attachment must be an object or uploaded file" unless raw.is_a?(Hash)

      filename = raw[:filename].to_s
      content = raw[:content].to_s
      raise InvalidAttachment, "attachment filename and content are required" if filename.blank? || content.blank?
      raise InvalidAttachment, too_large(filename) if oversized?(content)

      attachment.name ||= raw[:name].presence
      options = {io: StringIO.new(decode_base64(content, filename)), filename: filename}
      options[:content_type] = raw[:content_type] if raw[:content_type].present?
      attachment.file.attach(options)
      raise InvalidAttachment, too_large(filename) if attachment.file.blob.byte_size > MAX_FILE_SIZE
    end

    def too_large(filename)
      "attachment #{filename} exceeds #{MAX_FILE_SIZE / 1.megabyte} MB"
    end

    # Base64 inflates bytes by 4/3, so a longer payload is definitely over the limit once decoded.
    def oversized?(content)
      content.bytesize > MAX_FILE_SIZE * 4 / 3 + 4
    end

    def decode_base64(content, filename)
      Base64.strict_decode64(content.gsub(/\s+/, ""))
    rescue ArgumentError
      raise InvalidAttachment, "attachment #{filename} is not valid Base64"
    end
  end
end
