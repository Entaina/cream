class RecordMailer < ApplicationMailer
  def tracked_email(message:)
    @message = message
    @body = message.body
    @tracking_url = email_tracking_open_url(token: message.tracking_token)

    message.attachments.each do |file|
      attachments[file.filename.to_s] = file.download
    end

    mail(to: message.to_address, subject: message.subject)
  end

  def record_email(to:, subject:, body:, record:, user:)
    @body = body
    @record = record
    mail(to: to, subject: subject, from: user.email_address)
  end
end
