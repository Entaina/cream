class Booking < ApplicationRecord
  STATUSES = %w[confirmed cancelled].freeze
  MAX_GUESTS = 5
  TRACKING_METADATA_FIELDS = %w[
    booking_page_slug booking_page_name source_page referrer
    utm_source utm_medium utm_campaign utm_term utm_content
  ].freeze

  belongs_to :workspace
  belongs_to :booking_page
  belongs_to :booking_event_type
  belongs_to :person, optional: true
  belongs_to :deal, optional: true
  belongs_to :campaign, optional: true

  validates :first_name, :last_name, :email, :starts_at, :ends_at, :timezone, presence: true
  validates :first_name, :last_name, length: {minimum: 2}
  validates :email, format: {with: URI::MailTo::EMAIL_REGEXP}
  validates :message, length: {maximum: 500}, allow_blank: true
  validates :status, inclusion: {in: STATUSES}
  validate :guest_emails_valid

  scope :confirmed, -> { where(status: "confirmed") }

  def self.build_tracking_metadata(booking_page:, params:, request:)
    TRACKING_METADATA_FIELDS.index_with do |key|
      case key
      when "booking_page_slug" then booking_page.slug
      when "booking_page_name" then booking_page.name
      else params[key].presence
      end
    end.compact.merge(
      "user_agent" => request.user_agent,
      "ip" => request.remote_ip
    ).compact
  end

  def display_name
    [first_name, last_name].compact.join(" ")
  end

  def self.display_starts_at_with_zone(starts_at:, timezone:, locale: I18n.locale, format: :default)
    zone = ActiveSupport::TimeZone[timezone.presence] || Time.zone
    I18n.with_locale(locale) do
      I18n.t(
        "booking.display.datetime_with_zone",
        datetime: I18n.l(starts_at.in_time_zone(zone), format: format),
        timezone: timezone
      )
    end
  end

  def localized_starts_at(format: :default, locale: I18n.locale)
    zone = ActiveSupport::TimeZone[timezone] || Time.zone
    I18n.with_locale(locale) do
      I18n.l(starts_at.in_time_zone(zone), format: format)
    end
  end

  def localized_starts_at_with_zone(format: :default, locale: I18n.locale)
    self.class.display_starts_at_with_zone(starts_at:, timezone:, locale:, format:)
  end

  def all_attendee_emails
    [email, *guest_emails].map { |value| value.to_s.strip.downcase }.uniq
  end

  def confirmation_payload(locale: I18n.locale)
    payload = {
      id: id,
      event_type: booking_event_type.payload(locale:),
      starts_at: starts_at.iso8601,
      ends_at: ends_at.iso8601,
      timezone: timezone,
      display_starts_at: localized_starts_at_with_zone(locale:),
      attendee_name: display_name,
      attendee_email: email,
      guest_emails: guest_emails,
      location_type: booking_event_type.location_type,
      location_address: booking_event_type.location_address,
      meet_link: meet_link,
      google_event_link: google_event_link
    }
    if booking_event_type.reminder_will_send_at?(starts_at)
      payload[:reminder_minutes_before] = booking_event_type.reminder_minutes_before
    end
    payload[:confirmation_email] = true if booking_event_type.confirmation_email_enabled?
    payload
  end

  private

  def guest_emails_valid
    emails = Array(guest_emails).map(&:to_s).reject(&:blank?)
    if emails.size > MAX_GUESTS
      errors.add(:guest_emails, "allows at most #{MAX_GUESTS} guests")
      return
    end

    emails.each do |guest_email|
      unless guest_email.match?(URI::MailTo::EMAIL_REGEXP)
        errors.add(:guest_emails, "contains an invalid email")
        break
      end
    end
  end
end
