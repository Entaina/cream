class BookingConfirmationEmail
  def self.call(booking)
    new(booking).call
  end

  def self.tokens_for(booking)
    event_type = booking.booking_event_type
    locale = booking.guest_locale
    zone = ActiveSupport::TimeZone[booking.timezone] || Time.zone
    starts_at = booking.starts_at.in_time_zone(zone)

    location = if event_type.location_address.present?
      event_type.location_address
    else
      BookingEventType.location_type_label(event_type.location_type)
    end

    I18n.with_locale(locale) do
      {
        "locale" => locale,
        "event_name" => event_type.localized_name(locale),
        "date" => I18n.l(starts_at.to_date, format: :long),
        "time" => starts_at.strftime("%H:%M"),
        "date_time" => booking.localized_starts_at_with_zone(locale:),
        "duration" => event_type.duration_minutes.to_s,
        "timezone" => booking.timezone,
        "location" => location,
        "location_address" => event_type.location_address.to_s,
        "location_type" => BookingEventType.location_type_label(event_type.location_type),
        "meet_link" => booking.meet_link.to_s,
        "company" => booking.person&.company&.name.to_s,
        "confirmation_message" => event_type.localized_confirmation_message(locale),
        "phone" => booking.phone.to_s,
        "guest_message" => booking.message.to_s,
        "host_name" => booking.booking_page.name.to_s,
        "cancel_url" => booking.cancel_url,
        "reschedule_url" => booking.reschedule_url
      }
    end
  end

  def initialize(booking)
    @booking = booking
    @event_type = booking.booking_event_type
    @booking_page = booking.booking_page
  end

  def call
    template = @event_type.email_template
    return unless template

    extra_tokens = self.class.tokens_for(@booking)
    rendered_body = template.render_for(@booking, extra_tokens:)
    rendered_subject = template.render_subject_for(@booking, extra_tokens:)

    record = @booking.deal || @booking.person
    if record
      deliver_as_record_email(record:, template:, subject: rendered_subject, body: rendered_body)
    else
      deliver_without_record(subject: rendered_subject, body: rendered_body)
    end
  rescue => e
    Rails.logger.error("Booking confirmation email failed for Booking##{@booking.id}: #{e.class}: #{e.message}")
  end

  private

  # Bookings linked to a deal or person keep the email on that record's timeline.
  def deliver_as_record_email(record:, template:, subject:, body:)
    message = @booking_page.workspace.email_messages.create!(
      user: @booking_page.host,
      record: record,
      to_address: @booking.email,
      subject: subject,
      body: body
    )
    attach_template_files(message, template)
    SendViaGmailJob.perform_later(message.id)
  end

  # Bookings without CRM association send the email but leave no record behind.
  def deliver_without_record(subject:, body:)
    SendBookingConfirmationJob.perform_later(@booking.id, subject, body)
  end

  def attach_template_files(message, template)
    return unless template.attachments.attached?

    template.attachments.each { |file| message.attachments.attach(file.blob) }
  end
end
