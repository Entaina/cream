class SendViaGmailJob < ApplicationJob
  queue_as :default

  # Sends a record email through the user's connected Gmail account, reusing the
  # tracked_email template (so the open pixel still works). When Gmail isn't the
  # chosen channel (no connection / send disabled) it goes out over SMTP. If the
  # Gmail API call itself fails the message is flagged "failed" so the failure is
  # visible instead of being silently swallowed (or rerouted through SMTP, which
  # would never show up in the user's Gmail "Sent" folder).
  def perform(email_message_id)
    message = EmailMessage.find_by(id: email_message_id)
    return unless message

    unless message.route_via_gmail?
      deliver_via_smtp(message)
      message.update!(status: "sent")
      message.track_sent!
      return
    end

    connection = message.workspace.gmail_connections.find_by(user_id: message.user_id)
    mail = RecordMailer.tracked_email(message: message)
    # tracked_email only renders an HTML template, so the message is single-part
    # and #html_part is nil; fall back to the message body itself.
    html = (mail.html_part || mail).body.decoded
    result = GmailSender.new(connection).send_email(
      to: message.to_address,
      subject: message.subject,
      html: html,
      attachments: message.attachment_files
    )
    message.update!(
      status: "sent",
      gmail_message_id: result.gmail_message_id,
      gmail_thread_id: result.gmail_thread_id,
      rfc822_message_id: result.rfc822_message_id
    )
    message.track_sent!
  rescue GmailSender::Error => e
    Rails.logger.error("Gmail send failed for EmailMessage##{email_message_id}: #{e.message}")
    message&.update!(status: "failed")
  end

  private

  def deliver_via_smtp(message)
    RecordMailer.tracked_email(message: message).deliver_now
  end
end
