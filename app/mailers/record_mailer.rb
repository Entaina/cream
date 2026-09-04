class RecordMailer < ApplicationMailer
  def tracked_email(message:)
    @message = message
    @body = message.marketing_send? ?
      Marketing::LinkRewriter.rewrite(html: message.body, message: message, campaign: message.campaign) :
      message.body
    @tracking_url = email_tracking_open_url(token: message.tracking_token)

    message.attachments.each do |file|
      attachments[file.filename.to_s] = file.download
    end

    headers = marketing_headers(message) if message.marketing_send?
    mail(to: message.to_address, subject: message.subject, headers: headers || {})
  end

  private

  def marketing_headers(message)
    client = Marketing::Esp::Client.for(message)
    client.send(:headers)
  rescue StandardError
    {}
  end

  def record_email(to:, subject:, body:, record:, user:)
    @body = body
    @record = record
    mail(to: to, subject: subject, from: user.email_address)
  end
end
