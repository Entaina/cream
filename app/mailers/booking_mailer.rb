class BookingMailer < ApplicationMailer
  def reminder(booking)
    @booking = booking
    @event_type = booking.booking_event_type
    @booking_page = booking.booking_page

    with_mailer_locale(booking.guest_locale) do
      @starts_at_display = booking.localized_starts_at_with_zone(locale: booking.guest_locale)
      mail(to: booking.email, subject: reminder_subject)
    end
  end

  def host_notification(booking:, host:)
    @booking = booking
    @host = host
    @event_type = booking.booking_event_type
    @booking_page = booking.booking_page
    @starts_at_display = booking.localized_starts_at_with_zone
    @deal_url = booking.deal && deal_url(booking.deal)

    with_mailer_locale(host.locale) do
      attachments["event.ics"] = {
        mime_type: "text/calendar; charset=UTF-8; method=PUBLISH",
        content: BookingIcs.build(booking)
      }
      mail(to: host.email_address, subject: host_notification_subject)
    end
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
    I18n.t(
      "booking.mailer.host_notification.subject",
      event_name: @event_type.localized_name,
      guest_name: @booking.display_name
    )
  end

  def mailjet_workspace = @booking.workspace
end
