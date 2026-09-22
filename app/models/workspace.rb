class Workspace < ApplicationRecord
  include IanaTimeZone

  WORKSPACE_FEATURE_TOGGLES = {
    reports: :reports_enabled,
    marketing_attribution: :marketing_attribution_enabled,
    lead_scoring: :lead_scoring_enabled,
    webhooks: :webhooks_enabled,
    custom_fields: :custom_fields_enabled
  }.freeze

  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :invitations, dependent: :destroy
  has_many :companies, dependent: :destroy
  has_many :people, dependent: :destroy
  has_many :person_emails, dependent: :destroy
  has_many :deals, dependent: :destroy
  has_many :pipelines, dependent: :destroy
  has_many :pipeline_stages, through: :pipelines
  has_many :products, dependent: :destroy
  has_many :editions, dependent: :destroy
  has_many :notes, dependent: :destroy
  has_many :tasks, dependent: :destroy
  has_many :lists, dependent: :destroy
  has_many :activities, dependent: :destroy
  has_many :custom_fields, dependent: :destroy
  has_many :saved_views, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_many :record_attachments, dependent: :destroy
  has_many :email_templates, dependent: :destroy
  has_many :email_layouts, dependent: :destroy
  has_many :email_messages, dependent: :destroy
  has_many :gmail_connections, dependent: :destroy
  has_many :webhooks, dependent: :destroy
  has_many :automations, dependent: :destroy
  has_many :alert_rules, dependent: :destroy
  has_many :alert_conditions, dependent: :destroy
  has_many :slack_integrations, dependent: :destroy
  has_many :reports, dependent: :destroy
  has_many :sales_briefings, dependent: :destroy
  has_many :stage_triggers, dependent: :destroy
  has_many :stage_trigger_runs, dependent: :destroy
  has_many :stage_field_formats, dependent: :destroy
  has_many :stage_conditions, dependent: :destroy
  has_many :stripe_connections, dependent: :destroy
  has_one :mailjet_connection, dependent: :destroy
  has_one :beehiiv_connection, dependent: :destroy
  has_many :stripe_payments, dependent: :destroy
  has_many :lead_forms, dependent: :destroy
  has_many :lead_form_templates, dependent: :destroy
  has_many :lead_submissions, dependent: :destroy
  has_many :calendar_connections, dependent: :destroy
  has_many :booking_pages, dependent: :destroy
  has_many :bookings, dependent: :destroy
  has_many :subscription_types, dependent: :destroy
  has_many :email_subscriptions, dependent: :destroy
  has_many :email_suppressions, dependent: :destroy
  has_many :campaigns, dependent: :destroy
  has_many :segments, dependent: :destroy
  has_many :segment_memberships, dependent: :destroy
  has_many :campaign_sends, dependent: :destroy
  has_many :journeys, dependent: :destroy
  has_many :journey_enrollments, dependent: :destroy
  has_many :scoring_rules, dependent: :destroy
  has_many :page_views, dependent: :destroy
  has_many :product_interests, class_name: "Marketing::ProductInterest", dependent: :destroy
  has_many :privacy_policy_versions, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true, format: {with: /\A[a-z0-9-]+\z/}
  validates :time_zone, presence: true
  validate :okm_service_account_key_format, if: -> { okm_service_account_key.present? }

  scope :sales_director_enabled, -> { where(sales_director_enabled: true) }
  scope :okm_chat_enabled, -> { where(okm_chat_enabled: true) }

  def okm_configured?
    okm_drive_id.present? && okm_service_account_key.present?
  end

  def okm_service_account_client_email
    return unless okm_service_account_key.present?

    JSON.parse(okm_service_account_key)["client_email"]
  rescue JSON::ParserError
    nil
  end

  def briefing_actor
    memberships.admins.includes(:user).first&.user || users.first
  end

  def feature_enabled?(key)
    key = key.to_sym
    column = WORKSPACE_FEATURE_TOGGLES[key]
    return CreamFeatures.enabled?(key) unless column

    return public_send(column) if key == :custom_fields

    CreamFeatures.enabled?(key) && public_send(column)
  end

  before_validation :generate_slug, on: :create
  after_create :create_default_pipeline

  private

  def generate_slug
    self.slug ||= name&.parameterize
  end

  def create_default_pipeline
    Pipeline.create_default!(self)
  end

  def okm_service_account_key_format
    data = JSON.parse(okm_service_account_key)
    unless data.is_a?(Hash) && data["client_email"].present? && data["private_key"].present?
      errors.add(:okm_service_account_key, :invalid_service_account_json)
    end
  rescue JSON::ParserError
    errors.add(:okm_service_account_key, :invalid_json)
  end
end
