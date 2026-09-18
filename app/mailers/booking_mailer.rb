class BookingMailer < ApplicationMailer
  def reminder(booking)
    @booking = booking
    @event_type = booking.booking_event_type
    @booking_page = booking.booking_page
    @starts_at_display = booking.localized_starts_at_with_zone

    mail(to: booking.email, subject: reminder_subject)
  end

  def host_notification(booking:, host:)
    @booking = booking
    @host = host
    @event_type = booking.booking_event_type
    @booking_page = booking.booking_page
    @starts_at_display = booking.localized_starts_at_with_zone
    @deal_url = booking.deal && deal_url(booking.deal)

    mail(to: host.email_address, subject: host_notification_subject)
  end

  private

  def reminder_subject
    zone = ActiveSupport::TimeZone[@booking.timezone] || Time.zone
    date = @booking.starts_at.in_time_zone(zone).to_date
    I18n.t(
      "booking.mailer.reminder.subject",
      event_name: @event_type.localized_name,
      date: I18n.l(date, format: :long)
    )
  end

  def host_notification_subject
    "[Cream] Nueva reserva: #{@event_type.localized_name} · #{@booking.display_name}"
  end

  def mailjet_workspace = @booking.workspace
end
