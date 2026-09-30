module BookingPagesHelper
  def public_booking_page_body(&block)
    content_html = capture(&block)
    template = @booking_page&.workspace&.public_layout_template
    return content_html if template.blank?

    PublicLayoutTemplates::Renderer.render(
      template: template,
      content_html: content_html,
      workspace: @booking_page.workspace,
      view_context: self
    )
  rescue Liquid::Error
    content_html
  end

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
    zones = ([selected] + BOOKING_TIMEZONES).compact.uniq
    options_for_select(
      zones.to_h { |zone| [zone.tr("_", " "), zone] },
      selected
    )
  end

  def booking_location_type_options
    BookingEventType::LOCATION_TYPES.to_h do |type|
      [BookingEventType.location_type_label(type), type]
    end
  end

  def booking_color_options
    BookingEventType::COLORS.to_h do |color|
      [BookingEventType.color_label(color), color]
    end
  end

  def booking_event_type_color_class(color)
    BOOKING_EVENT_TYPE_COLOR_CLASSES.fetch(color.to_s, "bg-chicago-400")
  end

  def booking_page_form_stimulus_i18n
    I18n.t("booking.pages.form_js").stringify_keys
  end

  def booking_weekday_labels
    BookingEventType::WEEKDAYS.index_with { |day| I18n.t("booking.weekdays.#{day}") }
  end

  def booking_weekly_hours_stimulus_i18n
    I18n.t("booking.pages.weekly_hours_js").stringify_keys
  end

  def public_booking_stimulus_copy_json
    public_booking_stimulus_copy.to_json
  end

  def public_booking_stimulus_copy
    %i[es en].index_with do |locale|
      copy = I18n.t("booking.public_ui", locale: locale)
      copy = copy.deep_stringify_keys if copy.respond_to?(:deep_stringify_keys)
      copy.except("aria")
    end
  end
end
