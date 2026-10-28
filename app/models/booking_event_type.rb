class BookingEventType < ApplicationRecord
  include BookingSuccessTemplateAssignable
  include WorkspaceScopedAssociations

  LOCATION_TYPES = %w[google_meet physical to_be_decided].freeze
  COLORS = %w[hoki copperfield golden chicago green blue].freeze
  WEEKDAYS = %w[monday tuesday wednesday thursday friday saturday sunday].freeze
  DEFAULT_WEEKLY_HOURS = {
    "monday" => [["10:00", "14:00"], ["16:30", "20:00"]],
    "tuesday" => [["10:00", "14:00"], ["16:30", "20:00"]],
    "wednesday" => [["10:00", "14:00"], ["16:30", "20:00"]],
    "thursday" => [["10:00", "14:00"], ["16:30", "20:00"]],
    "friday" => [["10:00", "14:00"], ["16:30", "18:30"]],
    "saturday" => [],
    "sunday" => []
  }.freeze

  belongs_to :booking_page, inverse_of: :event_types
  belongs_to :email_template, optional: true

  attribute :reminder_minutes_before, :integer, default: 60

  validates :slug, presence: true, format: {with: /\A[a-z0-9-]+\z/}
  validates :slug, uniqueness: {scope: :booking_page_id}
  validates :duration_minutes, numericality: {greater_than: 0}
  validates :slot_increment_minutes, numericality: {greater_than: 0}
  validates :min_notice_hours, numericality: {greater_than_or_equal_to: 0}
  validates :reminder_minutes_before, numericality: {greater_than_or_equal_to: 0, allow_nil: true}
  validates :location_type, inclusion: {in: LOCATION_TYPES}
  validates :color, inclusion: {in: COLORS}
  validate :name_i18n_present
  validates_same_workspace :email_template

  before_validation :normalize_weekly_hours, :normalize_slug, :normalize_reminder_minutes_before

  scope :visible, -> { where(visible: true) }
  scope :ordered, -> { order(:position, :id) }

  def self.empty_weekly_hours
    WEEKDAYS.index_with { [] }
  end

  def self.blank_attributes
    {
      duration_minutes: 30,
      location_type: "google_meet",
      color: "hoki",
      weekly_hours: empty_weekly_hours,
      slot_increment_minutes: 15,
      min_notice_hours: 4,
      reminder_minutes_before: 60,
      buffer_before_minutes: 0,
      buffer_after_minutes: 0,
      visible: true,
      position: 0
    }
  end

  def self.location_type_label(type)
    I18n.t("booking.location_types.#{type}", default: type.to_s.humanize)
  end

  def self.color_label(color)
    I18n.t("booking.colors.#{color}", default: color.to_s.humanize)
  end

  def localized_name(locale = I18n.locale)
    fetch_i18n(name_i18n, locale)
  end

  def localized_description(locale = I18n.locale)
    fetch_i18n(description_i18n, locale)
  end

  def localized_confirmation_message(locale = I18n.locale)
    message = fetch_i18n(confirmation_message_i18n, locale)
    return message if message.present?

    I18n.with_locale(locale) do
      I18n.t("booking.mailer.confirmation.default_message")
    end
  end

  def google_meet?
    location_type == "google_meet"
  end

  def reminder_enabled?
    reminder_minutes_before.to_i.positive?
  end

  def confirmation_email_enabled?
    email_template.present?
  end

  def reminder_will_send_at?(starts_at)
    return false unless reminder_enabled?

    remind_at = starts_at - reminder_minutes_before.minutes
    remind_at > Time.current
  end

  def public_url
    Rails.application.routes.url_helpers.public_booking_event_type_url(
      booking_page.slug,
      slug,
      **booking_page.public_url_options
    )
  end

  def resolved_success_template
    success_template || booking_page.success_template
  end

  def payload(locale: I18n.locale)
    {
      slug: slug,
      name: localized_name(locale),
      description: localized_description(locale),
      duration_minutes: duration_minutes,
      color: color,
      location_type: location_type,
      location_address: location_address
    }
  end

  def hours_for_weekday(weekday_name)
    weekly_hours.fetch(weekday_name.to_s, [])
  end

  private

  def normalize_weekly_hours
    if weekly_hours.is_a?(String)
      begin
        self.weekly_hours = JSON.parse(weekly_hours)
      rescue JSON::ParserError
        self.weekly_hours = self.class.empty_weekly_hours
      end
    end

    self.weekly_hours = normalize_weekly_hours_hash(weekly_hours)
  end

  def normalize_weekly_hours_hash(value)
    return self.class.empty_weekly_hours if value.blank?

    WEEKDAYS.index_with do |day|
      Array(value[day]).filter_map do |window|
        next unless window.is_a?(Array) && window.size >= 2

        start_time = window[0].to_s.strip
        end_time = window[1].to_s.strip
        next if start_time.blank? || end_time.blank?

        [start_time, end_time]
      end
    end
  end

  def normalize_slug
    self.slug = slug.to_s.parameterize if slug.present?
  end

  def normalize_reminder_minutes_before
    self.reminder_minutes_before = nil if reminder_minutes_before.blank?
  end

  def name_i18n_present
    data = name_i18n.is_a?(Hash) ? name_i18n : {}
    return if data["es"].present?

    errors.add(:name_i18n, I18n.t("booking.errors.name_i18n_es_required"))
  end

  def fetch_i18n(hash, locale)
    data = hash.is_a?(Hash) ? hash : {}
    data[locale.to_s].presence || data["es"].presence || data.values.first.to_s
  end
end
