class BookingPage < ApplicationRecord
  HONEYPOT_FIELD = "_honeypot".freeze
  TIMESTAMP_FIELD = "_ts".freeze
  MIN_SECONDS_TO_SUBMIT = 3
  MAX_BOOKINGS_PER_EMAIL_PER_DAY = 5
  MAX_BOOKINGS_PER_PAGE_PER_HOUR = 100

  belongs_to :workspace
  belongs_to :host, class_name: "User"
  belongs_to :pipeline

  has_many :event_types, class_name: "BookingEventType", dependent: :destroy, inverse_of: :booking_page
  has_many :bookings, dependent: :destroy

  accepts_nested_attributes_for :event_types, allow_destroy: true, reject_if: :all_blank_event_type?

  validates :name, :slug, presence: true
  validates :slug, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/ }
  validate :associations_belong_to_workspace
  validate :calendar_ids_selected
  validate :event_types_present

  before_validation :normalize_slug

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name, :id) }

  def calendar_connection
    workspace.calendar_connections.find_by(user: host)
  end

  def ready_for_booking?
    active? && calendar_connection&.operational? && calendar_ids.present? && event_types.visible.exists?
  end

  def event_calendar_id
    calendar_ids.first
  end

  def localized_name(locale = I18n.locale)
    host.name.presence || name
  end

  def public_url
    Rails.application.routes.url_helpers.public_booking_page_url(slug, host: default_url_host)
  end

  def profile_payload(locale: I18n.locale)
    {
      name: localized_name(locale),
      avatar_url: avatar_url,
      logo_url: logo_url,
      welcome_message: welcome_message
    }
  end

  def self.signed_timestamp(at: Time.current)
    timestamp_verifier.generate(at.to_i)
  end

  def self.submitted_after_min_time?(token)
    issued_at = timestamp_verifier.verify(token.to_s)
    Time.current.to_i - issued_at.to_i >= MIN_SECONDS_TO_SUBMIT
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    false
  end

  def self.page_throttled?(booking_page)
    booking_page.bookings.where(created_at: 1.hour.ago..).count >= MAX_BOOKINGS_PER_PAGE_PER_HOUR
  end

  def self.email_throttled?(email)
    normalized = email.to_s.strip.downcase
    return false if normalized.blank?

    Booking.where(email: normalized, created_at: 24.hours.ago..).count >= MAX_BOOKINGS_PER_EMAIL_PER_DAY
  end

  def self.timestamp_verifier
    Rails.application.message_verifier("booking_page_timestamp")
  end
  private_class_method :timestamp_verifier

  private

  def normalize_slug
    self.slug = slug.to_s.parameterize if slug.present?
  end

  def calendar_ids_selected
    ids = Array(calendar_ids).map(&:to_s).reject(&:blank?)
    return if ids.any?

    errors.add(:calendar_ids, "selecciona al menos un calendario")
  end

  def all_blank_event_type?(attributes)
    slug = attributes["slug"].to_s.strip
    name = attributes["name_i18n"]
    name_es = name.is_a?(Hash) ? name["es"].to_s.strip : name.to_s.strip
    slug.blank? && name_es.blank?
  end

  def event_types_present
    types = event_types.reject(&:marked_for_destruction?)
    return if types.any? { |event_type| event_type.slug.present? || event_type.name_i18n.to_h["es"].present? }

    errors.add(:base, "Configura al menos un tipo de evento")
  end

  def associations_belong_to_workspace
    return if workspace.nil?

    errors.add(:pipeline, "must belong to the workspace") if pipeline && pipeline.workspace_id != workspace_id
    errors.add(:host, "must be a workspace member") if host && !workspace.users.exists?(id: host_id)
  end

  def default_url_host
    options = Rails.application.config.action_mailer.default_url_options
    host = options[:host]
    port = options[:port]
    return host if port.blank?

    "#{host}:#{port}"
  end
end
