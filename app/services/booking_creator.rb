class BookingCreator
  Conflict = Class.new(StandardError)
  ValidationError = Class.new(StandardError)

  Result = Data.define(:booking)

  def self.call(booking_page:, event_type:, params:, request:, client:)
    new(booking_page:, event_type:, params:, request:, client:).call
  end

  def initialize(booking_page:, event_type:, params:, request:, client:)
    @booking_page = booking_page
    @event_type = event_type
    @params = params.to_h.stringify_keys
    @request = request
    @client = client
    @timezone = ActiveSupport::TimeZone[@params["timezone"].presence || booking_page.timezone] ||
      ActiveSupport::TimeZone["UTC"]
  end

  def call
    validate!
    starts_at = parse_starts_at!
    ends_at = starts_at + @event_type.duration_minutes.minutes

    unless BookingAvailabilityService.slot_available?(
      booking_page: @booking_page,
      event_type: @event_type,
      starts_at:,
      timezone: @timezone.name,
      client: @client
    )
      raise Conflict, I18n.t("booking.errors.slot_unavailable")
    end

    google_event = create_google_event!(starts_at:, ends_at:)
    crm_result = BookingSubmissionProcessor.call(
      booking_page: @booking_page,
      event_type: @event_type,
      params: @params,
      request: @request
    )

    booking = Booking.create!(
      workspace: @booking_page.workspace,
      booking_page: @booking_page,
      booking_event_type: @event_type,
      person: crm_result&.person,
      deal: crm_result&.deal,
      first_name: @params["first_name"].to_s.strip,
      last_name: @params["last_name"].to_s.strip,
      email: normalized_email,
      phone: @params["phone"].presence,
      message: @params["message"].presence,
      guest_emails: normalized_guests,
      starts_at:,
      ends_at:,
      timezone: @timezone.name,
      google_event_id: google_event["id"],
      google_event_link: google_event["htmlLink"],
      meet_link: extract_meet_link(google_event),
      metadata: Booking.build_tracking_metadata(
        booking_page: @booking_page,
        params: @params,
        request: @request
      )
    )

    enqueue_reminder!(booking)
    enqueue_confirmation!(booking)

    Result.new(booking:)
  end

  private

  def enqueue_reminder!(booking)
    return unless @event_type.reminder_enabled?

    remind_at = booking.starts_at - @event_type.reminder_minutes_before.minutes
    return if remind_at <= Time.current

    BookingReminderJob.set(wait_until: remind_at).perform_later(booking.id)
  end

  def enqueue_confirmation!(booking)
    template = @event_type.email_template
    return unless template
    return unless booking.deal

    extra_tokens = booking_confirmation_tokens(booking)
    rendered_body = template.render_for(booking, extra_tokens:)
    rendered_subject = template.render_subject_for(booking, extra_tokens:)

    message = @booking_page.workspace.email_messages.create!(
      user: @booking_page.host,
      record: booking.deal,
      to_address: booking.email,
      subject: rendered_subject,
      body: rendered_body
    )
    SendViaGmailJob.perform_later(message.id)
  rescue StandardError => e
    Rails.logger.error("Booking confirmation email failed for Booking##{booking.id}: #{e.class}: #{e.message}")
  end

  def booking_confirmation_tokens(booking)
    zone = ActiveSupport::TimeZone[booking.timezone] || Time.zone
    starts_at = booking.starts_at.in_time_zone(zone)
    locale = @params["lang"].presence_in(%w[es en]) || I18n.locale

    location = if @event_type.location_address.present?
      @event_type.location_address
    else
      BookingEventType.location_type_label(@event_type.location_type)
    end

    I18n.with_locale(locale) do
      {
        "event_name" => @event_type.localized_name(locale),
        "date" => I18n.l(starts_at.to_date, format: :long),
        "time" => starts_at.strftime("%H:%M"),
        "duration" => @event_type.duration_minutes.to_s,
        "timezone" => booking.timezone,
        "location" => location,
        "meet_link" => booking.meet_link.to_s,
        "company" => booking.person&.company&.name.to_s
      }
    end
  end

  def validate!
    booking = Booking.new(
      first_name: @params["first_name"],
      last_name: @params["last_name"],
      email: @params["email"],
      phone: @params["phone"],
      message: @params["message"],
      guest_emails: normalized_guests,
      starts_at: Time.current,
      ends_at: Time.current + 1.hour,
      timezone: @timezone.name,
      workspace: @booking_page.workspace,
      booking_page: @booking_page,
      booking_event_type: @event_type
    )
    raise ValidationError, booking.errors.full_messages.to_sentence unless booking.valid?
    raise ValidationError, I18n.t("booking.errors.invalid_datetime") if @params["datetime"].blank?
  end

  def parse_starts_at!
    time = @timezone.parse(@params["datetime"].to_s)
    raise ValidationError, I18n.t("booking.errors.invalid_datetime") if time.nil?

    time.change(sec: 0)
  end

  def normalized_email
    @params["email"].to_s.strip.downcase
  end

  def normalized_guests
    Array(@params["guests"]).map { |email| email.to_s.strip.downcase }.reject(&:blank?).uniq
  end

  def create_google_event!(starts_at:, ends_at:)
    calendar_id = @booking_page.event_calendar_id
    summary = "#{@event_type.localized_name} — #{@params['first_name']} #{@params['last_name']}".strip
    description_lines = []
    description_lines << @params["message"] if @params["message"].present?
    description_lines << "Tel: #{@params['phone']}" if @params["phone"].present?
    description_lines << "Reservado via Cream"

    event = {
      summary: summary,
      description: description_lines.join("\n\n"),
      start: { dateTime: starts_at.iso8601, timeZone: @timezone.name },
      end: { dateTime: ends_at.iso8601, timeZone: @timezone.name },
      attendees: normalized_guests.map { |email| { email: } }.prepend({ email: normalized_email })
    }

    if @event_type.google_meet?
      event[:conferenceData] = {
        createRequest: {
          requestId: SecureRandom.uuid,
          conferenceSolutionKey: { type: "hangoutsMeet" }
        }
      }
    elsif @event_type.location_address.present?
      event[:location] = @event_type.location_address
    end

    @client.create_event(calendar_id:, event:)
  end

  def extract_meet_link(google_event)
    entry_points = google_event.dig("conferenceData", "entryPoints") || []
    video = entry_points.find { |entry| entry["entryPointType"] == "video" }
    video&.fetch("uri", nil)
  end
end
