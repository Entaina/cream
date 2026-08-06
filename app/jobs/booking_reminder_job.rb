class BookingReminderJob < ApplicationJob
  queue_as :default

  def perform(booking_id)
    booking = Booking.includes(:booking_event_type).find_by(id: booking_id)
    return unless booking&.status == "confirmed"
    return unless booking.booking_event_type.reminder_enabled?
    return if booking.starts_at <= Time.current

    BookingMailer.reminder(booking).deliver_now
  end
end
