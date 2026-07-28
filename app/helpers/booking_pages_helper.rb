module BookingPagesHelper
  BOOKING_TIMEZONES = [
    "Europe/Madrid",
    "Europe/London",
    "Europe/Paris",
    "Europe/Berlin",
    "America/New_York",
    "America/Chicago",
    "America/Los_Angeles",
    "America/Mexico_City",
    "America/Bogota",
    "America/Argentina/Buenos_Aires"
  ].freeze

  BOOKING_EVENT_TYPE_COLOR_CLASSES = {
    "hoki" => "bg-hoki-500",
    "copperfield" => "bg-copperfield-500",
    "golden" => "bg-golden-500",
    "chicago" => "bg-chicago-500",
    "green" => "bg-green-500",
    "blue" => "bg-blue-500"
  }.freeze

  def booking_timezone_options(selected)
    zones = ([ selected ] + BOOKING_TIMEZONES).compact.uniq
    options_for_select(
      zones.to_h { |zone| [ zone.tr("_", " "), zone ] },
      selected
    )
  end

  def booking_location_type_options
    BookingEventType::LOCATION_TYPES.to_h do |type|
      [ BookingEventType.location_type_label(type), type ]
    end
  end

  def booking_color_options
    BookingEventType::COLORS.to_h do |color|
      [ BookingEventType.color_label(color), color ]
    end
  end

  def booking_event_type_color_class(color)
    BOOKING_EVENT_TYPE_COLOR_CLASSES.fetch(color.to_s, "bg-chicago-400")
  end
end
