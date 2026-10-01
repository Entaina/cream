class BookingRescheduler
  Conflict = Class.new(StandardError)
  ValidationError = Class.new(StandardError)
  Unauthorized = Class.new(StandardError)

  Result = Data.define(:booking)

  def self.call(booking:, params:, client:)
    new(booking:, params:, client:).call
  end

  def initialize(booking:, params:, client:)
    @booking = booking
    @booking_page = booking.booking_page
    @event_type = booking.booking_event_type
    @params = params.to_h.stringify_keys
    @client = client
    @timezone = ActiveSupport::TimeZone[@params["timezone"].presence || booking.timezone] ||
      ActiveSupport::TimeZone["UTC"]
    @timezone_name = IanaTimeZone.canonical(@timezone.name) || "UTC"
  end

  def call
    raise Unauthorized, I18n.t("booking.errors.booking_not_modifiable") unless @booking.reschedulable?

    starts_at = parse_starts_at!
    ends_at = starts_at + @event_type.duration_minutes.minutes

    unless BookingAvailabilityService.slot_available?(
      booking_page: @booking_page,
      event_type: @event_type,
      starts_at:,
      timezone: @timezone_name,
      client: @client,
      ignore_booking: @booking
    )
      raise Conflict, I18n.t("booking.errors.slot_unavailable")
    end

    update_google_event!(starts_at:, ends_at:)
    @booking.update!(starts_at:, ends_at:, timezone: @timezone_name)

    enqueue_reminder!(@booking)
    BookingConfirmationEmail.call(@booking)

    Result.new(booking: @booking.reload)
  end

  private

  def parse_starts_at!
    raw = @params["datetime"].to_s.strip
    unless raw.match?(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2})?\z/)
      raise ValidationError, I18n.t("booking.errors.invalid_datetime")
    end

    time = @timezone.parse(raw)
    raise ValidationError, I18n.t("booking.errors.invalid_datetime") if time.nil?

    time.change(sec: 0)
  end

  def update_google_event!(starts_at:, ends_at:)
    return if @booking.google_event_id.blank? || @client.nil?

    calendar_id = @booking_page.event_calendar_id
    @client.update_event(
      calendar_id:,
      event_id: @booking.google_event_id,
      event: {
        start: google_event_time(starts_at),
        end: google_event_time(ends_at)
      }
    )
  end

  def google_event_time(time)
    local = time.in_time_zone(@timezone)
    {
      dateTime: local.strftime("%Y-%m-%dT%H:%M:%S"),
      timeZone: @timezone_name
    }
  end

  def enqueue_reminder!(booking)
    return unless @event_type.reminder_enabled?

    remind_at = booking.starts_at - @event_type.reminder_minutes_before.minutes
    return if remind_at <= Time.current

    BookingReminderJob.set(wait_until: remind_at).perform_later(booking.id, booking.starts_at.iso8601)
  end
end
