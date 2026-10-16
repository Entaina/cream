# Sends the guest confirmation email of a booking that has no CRM record
# (deal or person) to attach it to. Goes out through the host's Gmail when it
# can send, otherwise over SMTP. No EmailMessage row is created.
class SendBookingConfirmationJob < ApplicationJob
  queue_as :default

  def perform(booking_id, subject, body)
    booking = Booking.find_by(id: booking_id)
    return unless booking

    files = template_files(booking)
    connection = gmail_connection_for(booking)

    if connection
      html = ApplicationController.helpers.email_delivery_html(body)
      GmailSender.new(connection).send_email(to: booking.email, subject: subject, html: html, attachments: files)
    else
      BookingMailer.guest_confirmation(booking: booking, subject: subject, body: body, attachment_files: files).deliver_now
    end
  rescue GmailSender::Error => e
    Rails.logger.error("Gmail send failed for booking confirmation Booking##{booking_id}: #{e.message}")
  end

  private

  def gmail_connection_for(booking)
    return unless CreamFeatures.enabled?(:gmail_sync)

    connection = booking.workspace.gmail_connections.find_by(user_id: booking.booking_page.host_id)
    connection if connection&.connected? && connection.send_enabled?
  end

  def template_files(booking)
    template = booking.booking_event_type.email_template
    return [] unless template&.attachments&.attached?

    template.attachments.map do |file|
      {filename: file.filename.to_s, content_type: file.content_type, content: file.download}
    end
  end
end
