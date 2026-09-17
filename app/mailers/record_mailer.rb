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

    if message.marketing_send?
      marketing_headers(message)&.each { |name, value| headers[name] = value }
    else
      user = message.user
      if user&.email_address.present?
        headers[MailjetDeliveryInterceptor::SENDER_HEADER] = user.email_address
      end
    end

    mail_options = {
      to: message.to_address,
      subject: message.subject,
      layout: @full_document ? false : "mailer"
    }
    unless message.marketing_send?
      user = message.user
      if user&.email_address.present?
        mail_options[:from] = formatted_user_from(user)
        mail_options[:reply_to] = user.email_address
      end
    end
    mail(**mail_options)
  end

  def record_email(to:, subject:, body:, record:, user:)
    @body = body
    @record = record
    @full_document = full_html_document?(@body)
    @body_html = email_delivery_html(@body)
    mail(to: to, subject: subject, from: user.email_address, layout: @full_document ? false : "mailer")
  end

  private

  def formatted_user_from(user)
    if user.name.present?
      "#{user.name} <#{user.email_address}>"
    else
      user.email_address
    end
  end

  def marketing_headers(message)
    client = Marketing::Esp::Client.for(message)
    client.send(:headers)
  rescue
    {}
  end

  def mailjet_workspace
    @message&.workspace || @record&.workspace
  end
end
