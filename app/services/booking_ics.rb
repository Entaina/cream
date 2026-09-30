class BookingIcs
  PRODID = "-//Cream//Booking//EN".freeze

  def self.build(booking)
    new(booking).build
  end

  def initialize(booking)
    @booking = booking
  end

  def build
    lines = [
      "BEGIN:VCALENDAR",
      "VERSION:2.0",
      "PRODID:#{PRODID}",
      "CALSCALE:GREGORIAN",
      "METHOD:PUBLISH",
      "BEGIN:VEVENT",
      "UID:#{uid}",
      "DTSTAMP:#{stamp(Time.current)}",
      "DTSTART:#{stamp(@booking.starts_at)}",
      "DTEND:#{stamp(@booking.ends_at)}",
      "SUMMARY:#{escape(summary)}"
    ]
    lines << "DESCRIPTION:#{escape(description)}" if description.present?
    lines << "LOCATION:#{escape(location)}" if location.present?
    lines << "URL:#{escape(@booking.meet_link)}" if @booking.meet_link.present?
    lines << "END:VEVENT"
    lines << "END:VCALENDAR"
    "#{lines.map { |line| fold(line) }.join("\r\n")}\r\n"
  end

  private

  def uid
    "booking-#{@booking.id}@cream"
  end

  def stamp(time)
    time.utc.strftime("%Y%m%dT%H%M%SZ")
  end

  def summary
    "#{@booking.booking_event_type.localized_name} — #{@booking.display_name}"
  end

  def description
    [@booking.display_name, @booking.email, @booking.phone, @booking.message].compact_blank.join("\n")
  end

  def location
    event_type = @booking.booking_event_type
    if event_type.google_meet?
      @booking.meet_link.presence
    else
      event_type.location_address.presence
    end
  end

  def escape(text)
    text.to_s
      .gsub("\\", "\\\\")
      .gsub("\r\n", "\\n")
      .gsub("\n", "\\n")
      .gsub(",", "\\,")
      .gsub(";", "\\;")
  end

  def fold(line)
    return line if line.bytesize <= 75

    chunks = []
    current = +""
    line.each_char do |char|
      limit = chunks.empty? ? 75 : 74
      if current.present? && (current.bytesize + char.bytesize > limit)
        chunks << current
        current = +""
      end
      current << char
    end
    chunks << current if current.present?
    chunks.join("\r\n ")
  end
end
