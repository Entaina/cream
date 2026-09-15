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
    @timezone = ActiveSupport::TimeZone[timezone] || ActiveSupport::TimeZone["UTC"]
    @client = client
  end

  def monthly(month_string)
    @calendar_warning = nil
    month_start = Date.strptime("#{month_string}-01", "%Y-%m-%d")
    month_end = month_start.end_of_month
    range_start = month_start.beginning_of_day.in_time_zone(@timezone)
    range_end = month_end.end_of_day.in_time_zone(@timezone)
    busy = fetch_busy(range_start, range_end)

    days = (month_start..month_end).map do |date|
      available = day_has_slots?(date, busy)
      {date: date.iso8601, available: available}
    end

    Result.new(days:, slots: nil, warning: @calendar_warning)
  end

  def daily(date_string)
    @calendar_warning = nil
    date = Date.iso8601(date_string)
    range_start = date.beginning_of_day.in_time_zone(@timezone)
    range_end = date.end_of_day.in_time_zone(@timezone)
    busy = fetch_busy(range_start, range_end)
    slots = slots_for_date(date, busy).map { |time| time.strftime("%H:%M") }

    Result.new(days: nil, slots:, warning: @calendar_warning)
  end

  def slot_available?(starts_at)
    time = starts_at.in_time_zone(@timezone)
    return false unless within_booking_window?(time.to_date)
    return false unless slot_in_schedule?(time)

    busy = fetch_busy(time.beginning_of_day.in_time_zone(@timezone), time.end_of_day.in_time_zone(@timezone))
    !overlaps_busy?(slot_range(time), busy)
  end

  private

  def day_has_slots?(date, busy = nil)
    return false unless within_booking_window?(date)

    busy ||= fetch_busy(date.beginning_of_day.in_time_zone(@timezone), date.end_of_day.in_time_zone(@timezone))
    slots_for_date(date, busy).any?
  end

  def slots_for_date(date, busy)
    weekday = BookingEventType::WEEKDAYS[(date.wday == 0) ? 6 : date.wday - 1]
    windows = @event_type.hours_for_weekday(weekday)
    return [] if windows.blank?

    slots = []
    windows.each do |window|
      window_start, window_end = window
      cursor = @timezone.parse("#{date} #{window_start}")
      window_end_at = @timezone.parse("#{date} #{window_end}")
      increment = @event_type.slot_increment_minutes.to_i
      next if increment <= 0

      iterations = 0
      while cursor + event_total_minutes.minutes <= window_end_at
        iterations += 1
        break if iterations > 2_000

        next unless cursor >= min_bookable_time
        range = slot_range(cursor)
        slots << cursor unless overlaps_busy?(range, busy)
        cursor += increment.minutes
      end
    end
    slots
  end

  def slot_in_schedule?(time)
    slots_for_date(time.to_date, []).any? { |slot| slot == time.change(sec: 0) }
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
    today = Time.current.in_time_zone(@timezone).to_date
    return false if date < today
    return false if date > today + @booking_page.booking_window_days.days

    true
  end

  def min_bookable_time
    Time.current.in_time_zone(@timezone) + @event_type.min_notice_hours.hours
  end

  def fetch_busy(range_start, range_end)
    return [] if @client.nil?

    Timeout.timeout(GOOGLE_BUSY_TIMEOUT) do
      @client.free_busy(
        time_min: range_start,
        time_max: range_end,
        calendar_ids: @booking_page.calendar_ids,
        timezone: @timezone.name
      )
    end
  rescue Timeout::Error
    @calendar_warning ||= "Google Calendar no respondió a tiempo."
    []
  rescue GoogleCalendar::Error => e
    @calendar_warning = e.message
    []
  end
end
