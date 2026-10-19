class BookingPage < ApplicationRecord
  include BookingSuccessTemplateAssignable

  HONEYPOT_FIELD = "_honeypot".freeze
  TIMESTAMP_FIELD = "_ts".freeze
  MIN_SECONDS_TO_SUBMIT = 3
  MAX_BOOKINGS_PER_EMAIL_PER_DAY = 5
  MAX_BOOKINGS_PER_PAGE_PER_HOUR = 100
  CRM_ASSOCIATIONS = %w[deal person none].freeze

  Participant = Data.define(:user, :calendar_ids, :connection)

  belongs_to :workspace
  belongs_to :host, class_name: "User"
  belongs_to :pipeline, optional: true

  has_many :event_types, class_name: "BookingEventType", dependent: :destroy, inverse_of: :booking_page
  has_many :bookings, dependent: :destroy
  has_many :members, class_name: "BookingPageMember", dependent: :destroy, inverse_of: :booking_page, autosave: true
  has_many :co_hosts, through: :members, source: :user

  accepts_nested_attributes_for :event_types, allow_destroy: true, reject_if: :all_blank_event_type?

  validates :name, :slug, presence: true
  validates :slug, uniqueness: true, format: {with: /\A[a-z0-9-]+\z/}
  validates :crm_association, inclusion: {in: CRM_ASSOCIATIONS}
  validates :pipeline, presence: true, if: :crm_deal?
  validate :associations_belong_to_workspace
  validate :calendar_ids_selected
  validate :event_types_present

  before_validation :normalize_slug

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name, :id) }

  def crm_deal? = crm_association == "deal"

  def crm_person? = crm_association == "person"

  def crm_none? = crm_association == "none"

  def calendar_connection
    workspace.calendar_connections.find_by(user: host)
  end

  def ready_for_booking?
    active? && calendar_connection&.operational? && calendar_ids.present? && event_types.visible.exists? &&
      co_hosts_ready?
  end

  # Host first, then every co-host. Each participant carries only their own
  # selected calendars and Google connection.
  def participants
    [
      Participant.new(user: host, calendar_ids: Array(calendar_ids), connection: calendar_connection),
      *co_host_participants
    ]
  end

  def co_host_participants
    members.map do |member|
      Participant.new(user: member.user, calendar_ids: Array(member.calendar_ids), connection: member.calendar_connection)
    end
  end

  # A co-host without calendars or without an operational Google connection
  # has no free slots, so the page cannot offer any.
  def co_hosts_ready?
    co_host_participants.all? { |participant| participant.calendar_ids.present? && participant.connection&.operational? }
  end

  def participant?(user)
    return false if user.nil?

    host_id == user.id || members.any? { |member| member.user_id == user.id }
  end

  def calendar_ids_for(user)
    return Array(calendar_ids) if user.id == host_id

    Array(members.find { |member| member.user_id == user.id }&.calendar_ids)
  end

  def assign_calendar_ids_for(user, ids)
    ids = Array(ids).map(&:to_s).reject(&:blank?)
    if user.id == host_id
      self.calendar_ids = ids
    else
      members.find { |member| member.user_id == user.id }&.calendar_ids = ids
    end
  end

  # Assigns the attributes and the acting user's own calendars and saves
  # everything atomically, so co-host changes are rolled back on failure.
  def update_as(user, attributes, calendar_ids: nil)
    saved = false
    transaction do
      assign_attributes(attributes)
      assign_calendar_ids_for(user, calendar_ids) if !calendar_ids.nil? && participant?(user)
      saved = save
      raise ActiveRecord::Rollback unless saved
    end
    saved
  end

  def event_calendar_id
    calendar_ids.first
  end

  def localized_name(locale = I18n.locale)
    host.name.presence || name
  end

  def public_url
    Rails.application.routes.url_helpers.public_booking_page_url(slug, **public_url_options)
  end

  def public_url_options
    {host: default_url_host}
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

    errors.add(:calendar_ids, :calendar_ids_required)
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

    errors.add(:base, :event_types_required)
  end

  def associations_belong_to_workspace
    return if workspace.nil?

    errors.add(:pipeline, :must_belong_to_workspace) if pipeline && pipeline.workspace_id != workspace_id
    errors.add(:host, :must_be_workspace_member) if host && !workspace.users.exists?(id: host_id)
  end

  def default_url_host
    options = Rails.application.config.action_mailer.default_url_options
    host = options[:host]
    port = options[:port]
    return host if port.blank?

    "#{host}:#{port}"
  end

  private :default_url_host
end
