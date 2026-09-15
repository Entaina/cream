class RecordMailer < ApplicationMailer
  include ActionView::Helpers::SanitizeHelper
  include ActionView::Helpers::TextHelper
  include EmailHelper

  def tracked_email(message:)
    @message = message
    @body = message.marketing_send? ?
      Marketing::LinkRewriter.rewrite(html: message.body, message: message, campaign: message.campaign) :
      message.body
    @tracking_url = email_tracking_open_url(token: message.tracking_token)
    @full_document = full_html_document?(@body)
    @body_html = email_delivery_html(@body)

    message.attachments.each do |file|
      attachments[file.filename.to_s] = file.download
    end

    headers = marketing_headers(message) if message.marketing_send?
    mail(to: message.to_address, subject: message.subject, headers: headers || {}, layout: @full_document ? false : "mailer")
  end

  def record_email(to:, subject:, body:, record:, user:)
    @body = body
    @record = record
    @full_document = full_html_document?(@body)
    @body_html = email_delivery_html(@body)
    mail(to: to, subject: subject, from: user.email_address, layout: @full_document ? false : "mailer")
  end

  private

  def marketing_headers(message)
    client = Marketing::Esp::Client.for(message)
    client.send(:headers)
  rescue StandardError
    {}
  end

  def mailjet_workspace
    @message&.workspace || @record&.workspace
  end
end
