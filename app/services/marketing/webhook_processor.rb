module Marketing
  class WebhookProcessor
    def self.process!(payload:, workspace: nil)
      events = Array(payload["Events"] || payload["events"] || payload)
      events.each { |event| process_event!(event, workspace: workspace) }
    end

    def self.process_event!(event, workspace: nil)
      message = find_message(event, workspace: workspace)
      return unless message

      event_type = map_event_type(event["event"] || event["EventType"])
      return unless event_type

      email_event = EmailEvent.create!(
        email_message: message,
        event_type: event_type,
        url: event["url"],
        occurred_at: Time.zone.parse(event["time"].to_s) || Time.current,
        payload: event
      )
      apply_scoring!(message: message, event_type: event_type)
      enqueue_journey!(message: message, event_type: event_type)
      email_event
    end

    def self.find_message(event, workspace: nil)
      scope = workspace ? workspace.email_messages : EmailMessage
      custom_id = event["CustomID"]
      message = scope.find_by(id: custom_id) if custom_id.present?
      message ||= scope.find_by(esp_message_id: event["MessageID"].to_s) if event["MessageID"].present?
      message
    end
    private_class_method :find_message

    def self.apply_scoring!(message:, event_type:)
      person = message.workspace.people.with_email(message.to_address).first
      return unless person

      case event_type
      when "open"
        Marketing::ScoringEngine.apply_event!(person: person, event: "email_opened", metadata: { "email_message_id" => message.id })
      when "click"
        Marketing::ScoringEngine.apply_event!(person: person, event: "email_clicked", metadata: { "email_message_id" => message.id })
      end
    end
    private_class_method :apply_scoring!

    def self.enqueue_journey!(message:, event_type:)
      return unless event_type == "click"

      person = message.workspace.people.with_email(message.to_address).first
      JourneyTrigger.enqueue_email_clicked!(person: person) if person
    end
    private_class_method :enqueue_journey!

    def self.map_event_type(raw)
      case raw.to_s.downcase
      when "sent", "delivered" then "delivered"
      when "open", "opened" then "open"
      when "click", "clicked" then "click"
      when "bounce", "bounced" then "bounce"
      when "spam", "spamcomplaint" then "spam"
      when "unsub", "unsubscribed" then "unsub"
      when "blocked" then "blocked"
      end
    end
    private_class_method :map_event_type
  end
end
