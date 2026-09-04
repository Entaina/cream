module Marketing
  module Esp
    class Client
      BATCH_SIZE = 50

      def self.for(message, subscription_type: nil)
        adapter_class.new(message, subscription_type: subscription_type)
      end

      def self.adapter_class
        if ENV["MAILJET_API_KEY"].present? && ENV["MAILJET_SECRET_KEY"].present?
          MailjetAdapter
        else
          SmtpAdapter
        end
      end

      def initialize(message, subscription_type: nil)
        @message = message
        @subscription_type = subscription_type
      end

      def deliver!
        raise NotImplementedError
      end

      private

      attr_reader :message, :subscription_type

      def headers
        {
          "List-Unsubscribe" => list_unsubscribe_header,
          "List-Unsubscribe-Post" => "List-Unsubscribe=One-Click"
        }.compact
      end

      def list_unsubscribe_header
        person = message.workspace.people.with_email(message.to_address).first
        return unless person

        type = subscription_type || message.workspace.subscription_types.find_by(slug: "newsletter")
        slug = type&.slug || "newsletter"
        token = Marketing::PreferenceToken.generate(person: person)
        url = Rails.application.routes.url_helpers.public_email_unsubscribe_url(
          **Marketing::LinkRewriter.tracking_url_options,
          token: token,
          type: slug
        )
        "<#{url}>"
      end

      def tracking_open_url
        Rails.application.routes.url_helpers.email_tracking_open_url(
          **Marketing::LinkRewriter.tracking_url_options,
          token: message.tracking_token
        )
      end

      def append_open_pixel(html)
        return html unless message.marketing_send?

        pixel = %(<img src="#{tracking_open_url}" width="1" height="1" alt="" style="display:none">)
        html.include?("</body>") ? html.sub("</body>", "#{pixel}</body>") : "#{html}#{pixel}"
      end
    end
  end
end
