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
    @timezone_name = IanaTimeZone.canonical(@timezone.name) || "UTC"
  end

  def call
    validate!
    starts_at = parse_starts_at!
    ends_at = starts_at + @event_type.duration_minutes.minutes

    unless BookingAvailabilityService.slot_available?(
      booking_page: @booking_page,
      event_type: @event_type,
      starts_at:,
      timezone: @timezone_name,
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
      timezone: @timezone_name,
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
    notify_host!(booking)
    track_booking_activity!(booking)

    if booking.person
      assign_campaign_from_utm!(booking)
      Marketing::ScoringEngine.apply_event!(person: booking.person, event: "booking_created", metadata: booking.metadata)
      Marketing::JourneyTrigger.enqueue_booking_created!(person: booking.person, booking: booking)
      Marketing::SegmentWatcher.sync_person!(booking.person)
    end

    Result.new(booking:)
  end

  private

  def track_booking_activity!(booking)
    metadata = {
      "booking_id" => booking.id,
      "event_name" => @event_type.localized_name,
      "starts_at" => booking.starts_at.iso8601,
      "timezone" => booking.timezone,
      "guest" => booking.display_name
    }
    [booking.deal, booking.person].compact.uniq.each do |record|
      next unless record.respond_to?(:track_activity)

      record.track_activity("booking_created", user: @booking_page.host, metadata: metadata)
    end
  end

  def assign_campaign_from_utm!(booking)
    return unless CreamFeatures.enabled?(:marketing_campaigns)

    utm_campaign = booking.metadata["utm_campaign"]
    return if utm_campaign.blank?

    campaign = @booking_page.workspace.campaigns.find_or_create_by!(utm_campaign: utm_campaign) do |record|
      record.name = utm_campaign
      record.status = "sent"
    end
    booking.update!(campaign: campaign)
    booking.deal&.update!(campaign: campaign)
  end

  def notify_host!(booking)
    host = @booking_page.host
    AlertChannelDelivery.for(user: host, workspace: @booking_page.workspace).deliver do |channels|
      NotificationService.notify_booking(booking:) if channels.in_app?
      BookingMailer.host_notification(booking:, host:).deliver_later if channels.email?
    end
  end

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
    attach_template_files(message, template)
    SendViaGmailJob.perform_later(message.id)
  rescue => e
    Rails.logger.error("Booking confirmation email failed for Booking##{booking.id}: #{e.class}: #{e.message}")
  end

  def attach_template_files(message, template)
    return unless template.attachments.attached?

    template.attachments.each { |file| message.attachments.attach(file.blob) }
  end

  def booking_confirmation_tokens(booking)
    zone = ActiveSupport::TimeZone[booking.timezone] || Time.zone
    starts_at = booking.starts_at.in_time_zone(zone)
    locale = booking.guest_locale

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
      timezone: @timezone_name,
      workspace: @booking_page.workspace,
      booking_page: @booking_page,
      booking_event_type: @event_type
    )
    raise ValidationError, booking.errors.full_messages.to_sentence unless booking.valid?
    raise ValidationError, I18n.t("booking.errors.invalid_datetime") if @params["datetime"].blank?
  end

  # The public form sends a naive local datetime (YYYY-MM-DDTHH:MM:SS) in the
  # visitor's timezone. Reject anything carrying its own offset/zone so the
  # instant can never be reinterpreted in a different zone.
  def parse_starts_at!
    raw = @params["datetime"].to_s.strip
    unless raw.match?(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2})?\z/)
      raise ValidationError, I18n.t("booking.errors.invalid_datetime")
    end

    time = @timezone.parse(raw)
    raise ValidationError, I18n.t("booking.errors.invalid_datetime") if time.nil?

    time.change(sec: 0)
  end

  def normalized_email
    @params["email"].to_s.strip.downcase
  end

  def normalized_guests
    Array(@params["guests"]).map { |email| email.to_s.strip.downcase }.reject(&:blank?).uniq
  end

  def google_event_attendees
    emails = [normalized_email, *normalized_guests]
    host_email = organizer_email
    emails << host_email if host_email.present? && emails.exclude?(host_email)

    emails.map { |email| {email:} }
  end

  def organizer_email
    @booking_page.calendar_connection&.email.to_s.strip.downcase.presence
  end

  def create_google_event!(starts_at:, ends_at:)
    calendar_id = @booking_page.event_calendar_id
    summary = "#{@event_type.localized_name} — #{@params["first_name"]} #{@params["last_name"]}".strip
    description_lines = []
    description_lines << @params["message"] if @params["message"].present?
    description_lines << "Tel: #{@params["phone"]}" if @params["phone"].present?
    description_lines << "Reservado via Cream"

    event = {
      summary: summary,
      description: description_lines.join("\n\n"),
      start: google_event_time(starts_at),
      end: google_event_time(ends_at),
      attendees: google_event_attendees
    }

    if @event_type.google_meet?
      event[:conferenceData] = {
        createRequest: {
          requestId: SecureRandom.uuid,
          conferenceSolutionKey: {type: "hangoutsMeet"}
        }
      }
    elsif @event_type.location_address.present?
      event[:location] = @event_type.location_address
    end

    @client.create_event(calendar_id:, event:)
  end

  def google_event_time(time)
    local = time.in_time_zone(@timezone)
    {
      dateTime: local.strftime("%Y-%m-%dT%H:%M:%S"),
      timeZone: @timezone_name
    }
  end

  def extract_meet_link(google_event)
    entry_points = google_event.dig("conferenceData", "entryPoints") || []
    video = entry_points.find { |entry| entry["entryPointType"] == "video" }
    video&.fetch("uri", nil)
  end
end
