require "net/http"
require "json"

module Marketing
  module Esp
    class MailjetAdapter < Client
      API_URL = "https://api.mailjet.com/v3.1/send".freeze

      def deliver!
        unless connection&.connected?
          record_event!("blocked", payload: {"error" => "Mailjet is not configured for this workspace"})
          return false
        end

        response = post_message
        if response.is_a?(Net::HTTPSuccess)
          body = JSON.parse(response.body)
          message_id = body.dig("Messages", 0, "To", 0, "MessageID") || body.dig("Messages", 0, "MessageID")
          message.update!(esp_message_id: message_id.to_s) if message_id.present?
          record_event!("delivered", payload: JSON.parse(response.body))
          true
        else
          record_event!("blocked", payload: {"status" => response.code, "body" => response.body})
          false
        end
      rescue => e
        record_event!("blocked", payload: {"error" => e.message})
        false
      end

      private

      def connection
        @connection ||= message.workspace.mailjet_connection
      end

      def post_message
        uri = URI(API_URL)
        request = Net::HTTP::Post.new(uri)
        request.basic_auth(connection.api_key, connection.secret_key)
        request["Content-Type"] = "application/json"
        request.body = payload.to_json
        Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 10) { |http| http.request(request) }
      end

      def payload
        {
          Messages: [
            {
              From: {Email: connection.from_email, Name: from_name},
              To: [{Email: message.to_address}],
              Subject: message.subject,
              HTMLPart: rendered_body,
              CustomID: message.id.to_s,
              Headers: headers
            }
          ]
        }
      end

      def from_name
        connection.from_name.presence || message.user.name
      end

      def rendered_body
        body = message.body.to_s
        body = Marketing::LinkRewriter.rewrite(html: body, message: message, campaign: message.campaign) if message.marketing_send?
        append_open_pixel(body)
      end

      def record_event!(type, payload: {})
        EmailEvent.create!(
          email_message: message,
          event_type: type,
          occurred_at: Time.current,
          payload: payload
        )
      end
    end
  end
end
