class Workspace < ApplicationRecord
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
  has_many :email_messages, dependent: :destroy
  has_many :gmail_connections, dependent: :destroy
  has_many :webhooks, dependent: :destroy
  has_many :automations, dependent: :destroy
  has_many :slack_integrations, dependent: :destroy
  has_many :reports, dependent: :destroy
  has_many :sales_briefings, dependent: :destroy
  has_many :stage_triggers, dependent: :destroy
  has_many :stage_trigger_runs, dependent: :destroy
  has_many :stage_field_formats, dependent: :destroy
  has_many :stage_conditions, dependent: :destroy
  has_many :stripe_connections, dependent: :destroy
  has_many :stripe_payments, dependent: :destroy
  has_many :lead_forms, dependent: :destroy
  has_many :lead_submissions, dependent: :destroy
  has_many :calendar_connections, dependent: :destroy
  has_many :booking_pages, dependent: :destroy
  has_many :bookings, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/ }

  scope :sales_director_enabled, -> { where(sales_director_enabled: true) }
  scope :okm_chat_enabled, -> { where(okm_chat_enabled: true) }

  def briefing_actor
    memberships.admins.includes(:user).first&.user || users.first
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
end
