module Marketing
  # Computes when a journey "wait" step releases a contact.
  #
  # Step config keys:
  #   "minutes"       relative delay counted from arrival at the step
  #   "until_time"    optional "HH:MM" (workspace zone): after the delay, hold
  #                   until the next time the wall clock reads that time
  #   "weekdays_only" optional flag: if the result lands on Saturday/Sunday,
  #                   move it to Monday at the same wall-clock time
  class WaitScheduler
    TIME_FORMAT = /\A([01]\d|2[0-3]):[0-5]\d\z/

    def self.valid_until_time?(value)
      value.blank? || value.to_s.match?(TIME_FORMAT)
    end

    def initialize(config, zone:)
      @config = config.to_h.stringify_keys
      @zone = ActiveSupport::TimeZone[zone.to_s] || ActiveSupport::TimeZone[IanaTimeZone::DEFAULT_TIME_ZONE]
    end

    def next_run_at(from: Time.current)
      local = (from + minutes.minutes).in_time_zone(@zone).change(sec: 0)
      local = align_to_time(local) if until_time
      local = skip_weekend(local) if weekdays_only?
      local
    end

    def minutes
      raw = @config["minutes"]
      value = (raw.is_a?(Numeric) || raw.is_a?(String)) ? raw.to_i : 0
      return value if value.positive?

      (until_time || weekdays_only?) ? 0 : 1
    end

    def until_time
      value = @config["until_time"].to_s.strip
      value.match?(TIME_FORMAT) ? value : nil
    end

    def weekdays_only?
      ActiveModel::Type::Boolean.new.cast(@config["weekdays_only"]) == true
    end

    private

    def align_to_time(local)
      hour, min = until_time.split(":").map(&:to_i)
      candidate = @zone.local(local.year, local.month, local.day, hour, min)
      return candidate if candidate >= local

      next_day = local.to_date + 1
      @zone.local(next_day.year, next_day.month, next_day.day, hour, min)
    end

    def skip_weekend(local)
      date = local.to_date
      date += 1 while date.saturday? || date.sunday?
      return local if date == local.to_date

      @zone.local(date.year, date.month, date.day, local.hour, local.min)
    end
  end
end
