class BookingMailer < ApplicationMailer
  def reminder(booking)
    @booking = booking
    @event_type = booking.booking_event_type
    @booking_page = booking.booking_page
    @starts_at_in_zone = booking.starts_at.in_time_zone(booking.timezone)
    @starts_at_time = @starts_at_in_zone.strftime("%H:%M")

    mail(to: booking.email, subject: reminder_subject)
  end

  private

  def reminder_subject
    I18n.t(
      "booking.mailer.reminder.subject",
      event_name: @event_type.localized_name,
      date: I18n.l(@starts_at_in_zone.to_date, format: :long)
    )
  end
end
