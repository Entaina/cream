class BookingReminderJob < ApplicationJob
  queue_as :default

  def perform(booking_id, expected_starts_at = nil)
    booking = Booking.includes(:booking_event_type).find_by(id: booking_id)
    return unless booking&.status == "confirmed"
    return unless booking.booking_event_type.reminder_enabled?
    return if booking.starts_at <= Time.current
    if expected_starts_at.present?
      expected = Time.zone.parse(expected_starts_at.to_s)
      return if expected.nil?
      return if booking.starts_at.change(usec: 0) != expected.change(usec: 0)
    end

    BookingMailer.reminder(booking).deliver_now
  end
end
