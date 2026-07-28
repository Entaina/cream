class EmailFollowUpJob < ApplicationJob
  queue_as :default

  # Fires at follow_up_at. Reminds the sender only if the email was sent and
  # still has no reply — so "Mark replied" (clears follow-up) or cancelling a
  # scheduled email turns this into a no-op.
  def perform(email_message_id)
    message = EmailMessage.find_by(id: email_message_id)
    return unless message&.awaiting_follow_up?

    NotificationService.notify_email_followup(message: message) if CreamFeatures.enabled?(:notifications)
  end
end
