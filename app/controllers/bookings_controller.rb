class BookingsController < ApplicationController
  include RequiresFeature

  requires_feature :calendar_booking

  before_action :set_booking, only: %i[cancel]

  def index
    @bookings = policy_scope(current_workspace.bookings)
      .includes(:booking_page, :booking_event_type, :person, :deal)
      .order(starts_at: :desc)
    authorize Booking
  end

  def cancel
    authorize @booking, :cancel?
    connection = @booking.booking_page.calendar_connection
    client = connection&.connected? ? GoogleCalendar::Client.new(connection) : nil

    BookingCanceller.call(booking: @booking, client:)
    redirect_to bookings_path, notice: t("flashes.bookings.cancelled")
  rescue GoogleCalendar::Error => e
    redirect_to bookings_path, alert: e.message
  end

  private

  def set_booking
    @booking = policy_scope(current_workspace.bookings).find(params[:id])
  end
end
