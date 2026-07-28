class SendScheduledEmailJob < ApplicationJob
  queue_as :default

  # Delivers a scheduled email when its wait_until fires. Guards on the current
  # status so a cancelled (deleted) or already-sent message is a no-op — this is
  # what makes "cancel" possible without reaching into the job queue.
  #
  # Delegates the actual delivery to SendViaGmailJob so a deferred email honours
  # the Gmail-vs-SMTP channel evaluated at send time (SendViaGmailJob falls back
  # to SMTP and sets the final status itself).
  def perform(email_message_id)
    message = EmailMessage.find_by(id: email_message_id)
    return unless message&.scheduled?

    SendViaGmailJob.perform_now(message.id)
  end
end
