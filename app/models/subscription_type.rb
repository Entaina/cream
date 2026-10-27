class SubscriptionType < ApplicationRecord
  belongs_to :workspace
  has_many :email_subscriptions, dependent: :destroy

  RESERVED_CONSENT_FIELD_KEYS = (
    LeadForm::METADATA_FIELDS + %w[
      gdpr_consent _submission_key privacy_policy_hash product_id
      subscribe_all subscribe_all_label subscribe_all_exclude_slugs
    ]
  ).freeze

  CLIENT_PORTAL_CONSENT_OPTIONS = %w[none optional required].freeze

  DEFAULTS = [
    {
      name: "General",
      slug: "general",
      description: "Comunicaciones generales del workspace",
      consent_field_key: "marketing_consent",
      default_consent_label: "Acepto recibir comunicaciones comerciales"
    },
    {
      name: "Newsletter",
      slug: "newsletter",
      description: "Boletín y novedades",
      consent_field_key: "newsletter_opt_in",
      default_consent_label: "Quiero recibir la newsletter de entaina"
    },
    {
      name: "Producto",
      slug: "product",
      description: "Comunicaciones sobre productos y servicios"
    },
    {
      name: "Eventos",
      slug: "events",
      description: "Invitaciones y recordatorios de eventos"
    }
  ].freeze

  validates :name, :slug, presence: true
  validates :slug, uniqueness: {scope: :workspace_id}, format: {with: /\A[a-z0-9_-]+\z/}
  validates :consent_field_key,
    format: {with: LeadForm::FIELD_KEY_FORMAT},
    uniqueness: {scope: :workspace_id},
    allow_nil: true
  validates :client_portal_consent, inclusion: {in: CLIENT_PORTAL_CONSENT_OPTIONS}
  validate :consent_field_key_not_reserved

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :name, :id) }
  scope :included_in_subscribe_all, -> { active.where(excluded_from_subscribe_all: false) }
  scope :offered_in_client_portal, -> { active.where(client_portal_consent: %w[optional required]) }

  # Spanish is the base text (also used by lead forms); English falls back to it when left blank.
  def consent_label(locale = I18n.locale)
    (default_consent_label_en.presence if locale.to_s == "en") || default_consent_label.presence || name
  end

  def localized_description(locale = I18n.locale)
    (description_en.presence if locale.to_s == "en") || description
  end

  def client_portal_required?
    client_portal_consent == "required"
  end

  before_validation :normalize_slug
  before_validation :normalize_consent_field_key

  def self.ensure_defaults!(workspace)
    DEFAULTS.each_with_index do |attrs, index|
      type = workspace.subscription_types.find_or_initialize_by(slug: attrs[:slug])
      type.name = attrs[:name] if type.name.blank?
      type.description = attrs[:description] if type.description.blank?
      type.position = index if type.new_record?
      type.consent_field_key = attrs[:consent_field_key] if type.consent_field_key.blank? && attrs[:consent_field_key].present?
      type.default_consent_label = attrs[:default_consent_label] if type.default_consent_label.blank? && attrs[:default_consent_label].present?
      type.save! if type.new_record? || type.changed?
    end
  end

  private

  def normalize_slug
    self.slug = slug.to_s.parameterize(separator: "_") if slug.present?
  end

  def normalize_consent_field_key
    self.consent_field_key = consent_field_key.presence
  end

  def consent_field_key_not_reserved
    return if consent_field_key.blank?
    return unless RESERVED_CONSENT_FIELD_KEYS.include?(consent_field_key)

    errors.add(:consent_field_key, :reserved_consent_field_key)
  end
end
