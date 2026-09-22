require "timeout"

class BookingAvailabilityService
  Result = Data.define(:days, :slots, :warning)
  GOOGLE_BUSY_TIMEOUT = 8

  def self.monthly(booking_page:, event_type:, month:, timezone:, client:)
    new(booking_page:, event_type:, timezone:, client:).monthly(month)
  end

  def self.daily(booking_page:, event_type:, date:, timezone:, client:)
    new(booking_page:, event_type:, timezone:, client:).daily(date)
  end

  def self.slot_available?(booking_page:, event_type:, starts_at:, timezone:, client:)
    new(booking_page:, event_type:, timezone:, client:).slot_available?(starts_at)
  end

  def initialize(booking_page:, event_type:, timezone:, client:)
    @booking_page = booking_page
    @event_type = event_type
    @guest_timezone = ActiveSupport::TimeZone[timezone] || ActiveSupport::TimeZone["UTC"]
    @host_timezone = ActiveSupport::TimeZone[booking_page.timezone] || @guest_timezone
    @client = client
  end

  def monthly(month_string)
    @calendar_warning = nil
    month_start = Date.strptime("#{month_string}-01", "%Y-%m-%d")
    month_end = month_start.end_of_month
    busy = fetch_busy(
      local_beginning_of_day(@guest_timezone, month_start) - 1.day,
      local_end_of_day(@guest_timezone, month_end) + 1.day
    )

    days = (month_start..month_end).map do |date|
      {date: date.iso8601, available: day_has_slots?(date, busy)}
    end

    Result.new(days:, slots: nil, warning: @calendar_warning)
  end

  def daily(date_string)
    @calendar_warning = nil
    date = Date.iso8601(date_string)
    busy = fetch_busy(
      local_beginning_of_day(@guest_timezone, date) - 1.day,
      local_end_of_day(@guest_timezone, date) + 1.day
    )
    slots = slots_for_guest_date(date, busy).map { |time| time.strftime("%H:%M") }

    Result.new(days: nil, slots:, warning: @calendar_warning)
  end

  def slot_available?(starts_at)
    time = starts_at.in_time_zone(@guest_timezone).change(sec: 0)
    return false unless within_booking_window?(time.to_date)
    return false unless slot_in_schedule?(time)

    busy = fetch_busy(
      local_beginning_of_day(@guest_timezone, time.to_date) - 1.day,
      local_end_of_day(@guest_timezone, time.to_date) + 1.day
    )
    !overlaps_busy?(slot_range(time), busy)
  end

  private

  def day_has_slots?(date, busy = nil)
    return false unless within_booking_window?(date)

    busy ||= fetch_busy(
      local_beginning_of_day(@guest_timezone, date) - 1.day,
      local_end_of_day(@guest_timezone, date) + 1.day
    )
    slots_for_guest_date(date, busy).any?
  end

  # Weekly hours live in the booking page timezone. The public calendar date is
  # the visitor's; convert each host slot so 10:00 in Madrid stays 10:00 Madrid
  # on the host calendar even if the guest sees 04:00 in New York.
  def slots_for_guest_date(date, busy)
    increment = @event_type.slot_increment_minutes.to_i
    return [] if increment <= 0

    slots = []
    ((date - 1.day)..(date + 1.day)).each do |host_date|
      weekday = BookingEventType::WEEKDAYS[(host_date.wday == 0) ? 6 : host_date.wday - 1]
      windows = @event_type.hours_for_weekday(weekday)
      next if windows.blank?

      windows.each do |window_start, window_end|
        cursor = @host_timezone.parse("#{host_date} #{window_start}")
        window_end_at = @host_timezone.parse("#{host_date} #{window_end}")
        iterations = 0
        while cursor + event_total_minutes.minutes <= window_end_at
          iterations += 1
          break if iterations > 2_000

          guest_time = cursor.in_time_zone(@guest_timezone)
          if guest_time.to_date == date && cursor >= min_bookable_time
            slots << guest_time unless overlaps_busy?(slot_range(cursor), busy)
          end
          cursor += increment.minutes
        end
      end
    end
    slots.sort
  end

  def slot_in_schedule?(time)
    slots_for_guest_date(time.to_date, []).any? { |slot| slot.change(sec: 0) == time.change(sec: 0) }
  end

  def slot_range(start_time)
    buffer_before = @event_type.buffer_before_minutes.minutes
    buffer_after = @event_type.buffer_after_minutes.minutes
    {
      start: start_time - buffer_before,
      end: start_time + @event_type.duration_minutes.minutes + buffer_after
    }
  end

  def overlaps_busy?(range, busy)
    busy.any? do |period|
      range[:start] < period[:end] && range[:end] > period[:start]
    end
  end

  def event_total_minutes
    @event_type.duration_minutes +
      @event_type.buffer_before_minutes +
      @event_type.buffer_after_minutes
  end

  def within_booking_window?(date)
    today = Time.current.in_time_zone(@guest_timezone).to_date
    return false if date < today
    return false if date > today + @booking_page.booking_window_days.days

    true
  end

  def min_bookable_time
    Time.current + @event_type.min_notice_hours.hours
  end

  def local_beginning_of_day(zone, date)
    zone.local(date.year, date.month, date.day)
  end

  def local_end_of_day(zone, date)
    local_beginning_of_day(zone, date).end_of_day
  end

  def fetch_busy(range_start, range_end)
    return [] if @client.nil?

    Timeout.timeout(GOOGLE_BUSY_TIMEOUT) do
      @client.free_busy(
        time_min: range_start,
        time_max: range_end,
        calendar_ids: @booking_page.calendar_ids,
        timezone: @host_timezone.tzinfo.name
      )
    end
  rescue Timeout::Error
    @calendar_warning ||= I18n.t("booking.warnings.calendar_timeout")
    []
  rescue GoogleCalendar::Error => e
    @calendar_warning = e.message
    []
  end
end
