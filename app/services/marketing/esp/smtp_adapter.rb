module Marketing
  module Esp
    class SmtpAdapter < Client
      def deliver!
        RecordMailer.tracked_email(message: message).deliver_now
        record_event!("sent")
        true
      rescue => e
        record_event!("blocked", payload: {"error" => e.message})
        false
      end

      private

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
