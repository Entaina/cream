class BookingCanceller
  Result = Data.define(:booking)

  def self.call(booking:, client: nil)
    new(booking:, client:).call
  end

  def initialize(booking:, client: nil)
    @booking = booking
    @client = client
  end

  def call
    return Result.new(booking: @booking) if @booking.status == "cancelled"

    delete_google_event! if @booking.google_event_id.present? && @client
    @booking.update!(status: "cancelled")

    Result.new(booking: @booking)
  end

  private

  def delete_google_event!
    @client.delete_event(
      calendar_id: @booking.booking_page.event_calendar_id,
      event_id: @booking.google_event_id
    )
  end
end
