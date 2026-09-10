module Marketing
  module Beehiiv
    class WebhookProcessor
      HANDLED_EVENTS = %w[
        subscription.created
        subscription.confirmed
        subscription.deleted
      ].freeze

      def self.process!(publication:, payload:)
        new(publication:, payload:).process!
      end

      def initialize(publication:, payload:)
        @publication = publication
        @payload = payload.is_a?(Hash) ? payload : {}
      end

      def process!
        event_type = @payload["event_type"].to_s
        return :ignored unless HANDLED_EVENTS.include?(event_type)

        record = @payload["data"].presence || {}
        SubscriberSync.apply!(
          publication: @publication,
          record: record,
          source: "beehiiv:webhook",
          event_type: event_type
        )
        :processed
      end
    end
  end
end
