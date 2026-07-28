# frozen_string_literal: true

# Demo only: idempotent seed of example public booking page (Calendly parity).
# Production pages should be created and configured entirely from Reservas in the UI.
# Run BookingPagesExample.seed!(workspace:, user:).
module BookingPagesExample
  DEFAULT_PIPELINE = "Proyectos"

  WEEKLY_HOURS = BookingEventType::DEFAULT_WEEKLY_HOURS

  FORMATION_WEEKLY_HOURS = {
    "monday" => [ [ "10:00", "14:00" ] ],
    "tuesday" => [ [ "10:00", "14:00" ] ],
    "wednesday" => [ [ "10:00", "14:00" ] ],
    "thursday" => [ [ "10:00", "14:00" ] ],
    "friday" => [ [ "10:00", "14:00" ] ],
    "saturday" => [],
    "sunday" => []
  }.freeze

  PAGE = {
    slug: "alex",
    name: "Alex Example",
    welcome_message: "Elige cuándo quedar conmigo. Recibirás la invitación de calendario por email.",
    timezone: "Europe/Madrid",
    booking_window_days: 60,
    calendar_ids: [ "primary" ],
    active: true
  }.freeze

  EVENT_TYPES = [
    {
      slug: "sesion-formacion",
      name_i18n: { "es" => "Formación", "en" => "Training session" },
      description_i18n: { "es" => "Sesión de formación presencial.", "en" => "In-person training session." },
      duration_minutes: 240,
      color: "copperfield",
      location_type: "physical",
      location_address: "123 Example St, Madrid",
      weekly_hours: FORMATION_WEEKLY_HOURS,
      slot_increment_minutes: 15,
      min_notice_hours: 4,
      buffer_before_minutes: 0,
      buffer_after_minutes: 0,
      visible: true,
      position: 0
    },
    {
      slug: "video",
      name_i18n: { "es" => "Reunión On-line", "en" => "Online meeting" },
      description_i18n: {
        "es" => "Salvo que acordemos lo contrario nos vemos en el enlace de Google Meet que recibirás en la invitación de calendario.",
        "en" => "Unless we agree otherwise, we'll meet on the Google Meet link included in your calendar invitation."
      },
      duration_minutes: 30,
      color: "hoki",
      location_type: "google_meet",
      weekly_hours: WEEKLY_HOURS,
      slot_increment_minutes: 15,
      min_notice_hours: 4,
      buffer_before_minutes: 0,
      buffer_after_minutes: 0,
      visible: true,
      position: 1
    },
    {
      slug: "reunion",
      name_i18n: { "es" => "Reunión presencial", "en" => "In-person meeting" },
      description_i18n: {
        "es" => "Para tener una reunión presencial, luego acordamos dónde nos vemos.",
        "en" => "For an in-person meeting, we'll agree on where to meet."
      },
      duration_minutes: 60,
      color: "golden",
      location_type: "physical",
      location_address: "456 Demo Ave, Madrid",
      weekly_hours: WEEKLY_HOURS,
      slot_increment_minutes: 15,
      min_notice_hours: 4,
      buffer_before_minutes: 0,
      buffer_after_minutes: 0,
      visible: true,
      position: 2
    },
    {
      slug: "comidas",
      name_i18n: { "es" => "Comida", "en" => "Lunch" },
      description_i18n: { "es" => "Coordinaremos el lugar.", "en" => "We'll coordinate the location." },
      duration_minutes: 90,
      color: "chicago",
      location_type: "to_be_decided",
      weekly_hours: WEEKLY_HOURS,
      slot_increment_minutes: 15,
      min_notice_hours: 4,
      buffer_before_minutes: 0,
      buffer_after_minutes: 0,
      visible: true,
      position: 3
    }
  ].freeze

  def self.seed!(workspace:, user:)
    host = resolve_host!(workspace:, user:)
    pipeline = ensure_pipeline!(workspace)

    page = workspace.booking_pages.find_or_initialize_by(slug: PAGE.fetch(:slug))
    page.assign_attributes(
      name: PAGE.fetch(:name),
      host: host,
      pipeline: pipeline,
      welcome_message: PAGE.fetch(:welcome_message),
      timezone: PAGE.fetch(:timezone),
      booking_window_days: PAGE.fetch(:booking_window_days),
      calendar_ids: PAGE.fetch(:calendar_ids),
      active: PAGE.fetch(:active)
    )

    EVENT_TYPES.each do |definition|
      seed_event_type!(page:, definition:)
    end

    page.save!

    page
  end

  def self.seed_event_type!(page:, definition:)
    event_type = page.event_types.find_or_initialize_by(slug: definition.fetch(:slug))
    event_type.assign_attributes(
      name_i18n: definition.fetch(:name_i18n),
      description_i18n: definition.fetch(:description_i18n),
      duration_minutes: definition.fetch(:duration_minutes),
      color: definition.fetch(:color),
      location_type: definition.fetch(:location_type),
      location_address: definition[:location_address],
      weekly_hours: definition.fetch(:weekly_hours),
      slot_increment_minutes: definition.fetch(:slot_increment_minutes),
      min_notice_hours: definition.fetch(:min_notice_hours),
      buffer_before_minutes: definition.fetch(:buffer_before_minutes, 0),
      buffer_after_minutes: definition.fetch(:buffer_after_minutes, 0),
      visible: definition.fetch(:visible, true),
      position: definition.fetch(:position, 0)
    )
    event_type.save! if page.persisted?
    event_type
  end

  def self.resolve_host!(workspace:, user:)
    host_email = ENV.fetch("CREAM_BOOKING_HOST_EMAIL", "alex@example.com").strip.downcase
    workspace.users.find_by(email_address: host_email) || workspace.briefing_actor || user
  end

  def self.ensure_pipeline!(workspace)
    default = Pipeline.default_for(workspace) || Pipeline.create_default!(workspace)
    workspace.pipelines.find_by(name: DEFAULT_PIPELINE) || default
  end
end
