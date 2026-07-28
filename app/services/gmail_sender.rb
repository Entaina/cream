require "net/http"
require "json"

# Sends mail through the Gmail API on behalf of a connected user, refreshing the
# access token when it has expired. HTTP is done with Net::HTTP so it can be
# stubbed in specs (no real Google calls).
class GmailSender
  include GmailTokenRefresh

  Error = Class.new(StandardError)
  SendResult = Data.define(:gmail_message_id, :gmail_thread_id, :rfc822_message_id)

  SEND_URI = URI("https://gmail.googleapis.com/gmail/v1/users/me/messages/send")

  def initialize(connection)
    @connection = connection
  end

  def send_email(to:, subject:, html:, rfc822_message_id: nil, attachments: [])
    unless @connection.can_send?
      raise Error, "Gmail send permission not granted for this connection"
    end

    rfc822_message_id ||= generate_message_id

    bearer = ensure_access_token!(@connection)

    raw = Base64.urlsafe_encode64(build_mime(to: to, subject: subject, html: html, message_id: rfc822_message_id, attachments: attachments))
    response = post_json(SEND_URI, { raw: raw }, bearer: bearer)
    raise Error, "send failed (#{response.code}): #{response.body}" unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)
    SendResult.new(
      gmail_message_id: data["id"],
      gmail_thread_id: data["threadId"],
      rfc822_message_id: rfc822_message_id
    )
  end

  private

  def generate_message_id
    "<#{SecureRandom.uuid}@#{message_id_domain}>"
  end

  def message_id_domain
    host = URI.parse(ENV.fetch("CREAM_APP_URL", "http://localhost:3000")).host
    host.presence || @connection.email.to_s.split("@", 2).last || "cream.local"
  rescue URI::InvalidURIError
    @connection.email.to_s.split("@", 2).last || "cream.local"
  end

  def build_mime(to:, subject:, html:, message_id:, attachments: [])
    mail = Mail.new
    mail.from = @connection.email
    mail.to = to
    mail.subject = subject
    mail.message_id = message_id

    if attachments.any?
      mail.html_part = Mail::Part.new do
        content_type "text/html; charset=UTF-8"
        body html
      end

      attachments.each do |attachment|
        mail.attachments[attachment[:filename]] = {
          mime_type: attachment[:content_type],
          content: attachment[:content]
        }
      end
    else
      mail.content_type = "text/html; charset=UTF-8"
      mail.body = html
    end

    mail.to_s
  end
end
