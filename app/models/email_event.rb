class EmailEvent < ApplicationRecord
  EVENT_TYPES = %w[delivered open click bounce spam unsub blocked].freeze

  belongs_to :email_message

  validates :event_type, inclusion: { in: EVENT_TYPES }
  validates :occurred_at, presence: true

  after_create :sync_message_counters
  after_create :maybe_suppress

  private

  def sync_message_counters
    case event_type
    when "open"
      email_message.update!(opened_at: occurred_at, status: "opened") unless email_message.opened?
    when "click"
      email_message.increment!(:clicks_count)
    end
  end

  def maybe_suppress
    workspace = email_message.workspace
    address = payload["email"].presence || email_message.to_address
    person = workspace.people.with_email(address).first

    case event_type
    when "bounce"
      return unless hard_bounce?

      EmailSuppression.suppress!(workspace: workspace, address: address, reason: "hard_bounce", metadata: { "email_event_id" => id })
    when "spam"
      EmailSuppression.suppress!(workspace: workspace, address: address, reason: "spam_complaint", metadata: { "email_event_id" => id })
    when "unsub"
      Marketing::ConsentService.unsubscribe_all!(person: person, source: "webhook_unsub") if person
      EmailSuppression.suppress!(workspace: workspace, address: address, reason: "unsubscribe", metadata: { "email_event_id" => id })
    end
  end

  def hard_bounce?
    return true if payload["hard_bounce"] == true
    return false if payload["hard_bounce"] == false

    payload["error_related_to"].to_s != "recipient" || payload["error"].to_s.exclude?("soft")
  end
end
