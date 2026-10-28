class Person < ApplicationRecord
  include CrmRecord
  include WorkspaceScopedAssociations

  SOURCES = {
    "web_form" => "Formulario web",
    "booking" => "Reserva online",
    "referral" => "Recomendado",
    "team_member" => "Lo trae alguien del equipo",
    "beehiiv" => "Beehiiv",
    "offer_share" => "Propuesta compartida",
    "portal_invite" => "Invitación al portal"
  }.freeze

  INTERNAL_NOTES_MAX_LENGTH = 50_000
  LIFECYCLE_STAGES = %w[subscriber lead mql sql opportunity customer evangelist].freeze

  belongs_to :company
  belongs_to :brought_by, class_name: "User", optional: true
  has_many :deal_contacts, dependent: :destroy
  has_many :offer_views, dependent: :destroy
  has_many :offer_share_links, dependent: :destroy
  has_many :deals, through: :deal_contacts
  has_many :outgoing_relationships, class_name: "PersonRelationship",
    foreign_key: :from_person_id, dependent: :destroy, inverse_of: :from_person
  has_many :incoming_relationships, class_name: "PersonRelationship",
    foreign_key: :to_person_id, dependent: :destroy, inverse_of: :to_person
  has_many :person_emails, dependent: :destroy
  has_many :suggested_stripe_payments, class_name: "StripePayment",
    foreign_key: :suggested_person_id, dependent: :nullify, inverse_of: :suggested_person
  has_many :email_subscriptions, dependent: :destroy
  has_many :lead_submissions, dependent: :destroy
  has_many :bookings, dependent: :nullify
  has_many :journey_enrollments, dependent: :destroy
  has_many :page_views, dependent: :nullify
  has_many :segment_memberships, dependent: :destroy
  has_many :product_interests, class_name: "Marketing::ProductInterest", dependent: :destroy

  accepts_nested_attributes_for :person_emails, allow_destroy: true,
    reject_if: ->(attrs) { attrs[:address].blank? && attrs[:id].blank? }

  validates :lifecycle_stage, inclusion: {in: LIFECYCLE_STAGES}
  validates :internal_notes, length: {maximum: INTERNAL_NOTES_MAX_LENGTH}
  validates :first_name, presence: true, unless: -> { last_name.present? }
  validates :email, format: {with: URI::MailTo::EMAIL_REGEXP}, allow_blank: true
  validates :source, inclusion: {in: SOURCES.keys}, allow_blank: true
  validates :brought_by_id, presence: true, if: -> { source == "team_member" }
  validate :brought_by_in_workspace, if: -> { brought_by_id.present? }
  validates_same_workspace :company
  validate :at_most_one_primary_email

  before_validation :clear_brought_by_unless_team_source
  before_validation :default_first_contact_on, on: :create
  before_validation :normalize_email_column
  before_validation :assign_workspace_to_person_emails
  before_validation :ensure_primary_email
  after_save :sync_person_emails_from_column, if: :saved_change_to_email?
  after_update :enqueue_lifecycle_journey, if: :saved_change_to_lifecycle_stage?

  scope :search, ->(q) {
    if q.present?
      left_joins(:person_emails)
        .where(
          "people.first_name ILIKE :q OR people.last_name ILIKE :q OR people.email ILIKE :q OR people.job_title ILIKE :q OR person_emails.address ILIKE :q",
          q: "%#{sanitize_sql_like(q)}%"
        )
        .distinct
    end
  }

  scope :with_email, ->(email) {
    normalized = email.to_s.strip.downcase
    next none if normalized.blank?

    left_joins(:person_emails)
      .where("LOWER(TRIM(person_emails.address)) = :email OR LOWER(TRIM(people.email)) = :email", email: normalized)
      .distinct
  }

  def self.find_by_email(workspace, email)
    workspace.people.with_email(email).first
  end

  def relationships_for_display
    outgoing = outgoing_relationships.includes(:to_person).map { |relationship| [relationship, self] }
    incoming = incoming_relationships.includes(:from_person).map { |relationship| [relationship, self] }
    (outgoing + incoming).sort_by { |relationship, viewer| relationship.other_person(viewer).display_name.downcase }
  end

  def display_name
    [first_name, last_name].reject(&:blank?).join(" ").presence || email
  end
  alias_method :full_name, :display_name

  # Email used for client portal access (primary column first, then person_emails).
  def client_portal_email
    return unless workspace

    candidates = []
    candidates << email if email.present?
    person_emails.order(:created_at).pluck(:address).each { |address| candidates << address if address.present? }
    candidates.uniq.each do |address|
      normalized = OfferAccessGrant.normalize_email(address)
      next if normalized.blank?

      return normalized if ClientPortal::Access.allowed?(workspace: workspace, email: normalized)
    end
    nil
  end

  def initials
    [first_name, last_name].reject(&:blank?).first(2).map { |w| w[0] }.join.upcase.presence || "?"
  end

  def primary_email_record
    person_emails.find(&:primary?) || person_emails.min_by(&:created_at)
  end

  def add_email!(address, primary: false)
    normalized = address.to_s.strip.downcase
    return if normalized.blank?

    record = person_emails.find_by("LOWER(TRIM(address)) = ?", normalized) ||
      person_emails.build(address: normalized)
    record.workspace = workspace
    record.primary = primary || person_emails.none?
    record.save!
    record
  end

  def refresh_primary_email_column!
    primary_address = person_emails.where(primary: true).pick(:address)
    primary_address ||= person_emails.order(:created_at).pick(:address)
    update_column(:email, primary_address)
  end

  private

  def clear_brought_by_unless_team_source
    self.brought_by_id = nil unless source == "team_member"
  end

  def default_first_contact_on
    self.first_contact_on = Date.current if first_contact_on.blank?
  end

  def brought_by_in_workspace
    return if workspace.nil?

    unless workspace.users.exists?(id: brought_by_id)
      errors.add(:brought_by_id, :must_be_workspace_member)
    end
  end

  def normalize_email_column
    return if email.blank?

    parsed = EmailAddressParser.parse(email)
    self.email = parsed&.email || email.to_s.strip.downcase.presence
    EmailAddressParser.apply_name_to_record!(self, parsed)
  end

  def assign_workspace_to_person_emails
    person_emails.each do |record|
      record.workspace = workspace if record.workspace.nil? && workspace.present?
    end
  end

  def ensure_primary_email
    active = person_emails.reject(&:marked_for_destruction?)
    return if active.empty?
    return if active.any?(&:primary?)

    active.first.primary = true
  end

  def at_most_one_primary_email
    primaries = person_emails.reject(&:marked_for_destruction?).count(&:primary?)
    return if primaries <= 1

    errors.add(:base, :single_primary_email)
  end

  def sync_person_emails_from_column
    return if @syncing_person_emails

    @syncing_person_emails = true
    if email.present?
      record = person_emails.find_by("LOWER(TRIM(address)) = ?", email) ||
        person_emails.build(address: email)
      record.workspace = workspace
      record.primary = true
      record.save!
    else
      person_emails.where(primary: true).update_all(primary: false)
      update_column(:email, nil)
    end
  ensure
    @syncing_person_emails = false
  end

  def enqueue_lifecycle_journey
    from, to = saved_change_to_lifecycle_stage
    Marketing::JourneyTrigger.enqueue_lifecycle_changed!(person: self, from: from, to: to)
  end
end
