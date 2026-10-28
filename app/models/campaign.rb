class Campaign < ApplicationRecord
  include WorkspaceScopedAssociations

  STATUSES = %w[draft scheduled sending sent].freeze

  belongs_to :workspace
  belongs_to :email_template, optional: true
  belongs_to :email_layout, optional: true
  has_many :campaign_sends, dependent: :destroy
  has_many :email_messages, dependent: :nullify
  has_many :lead_submissions, dependent: :nullify
  has_many :bookings, dependent: :nullify
  has_many :deals, dependent: :nullify

  validates :name, presence: true
  validates :status, inclusion: {in: STATUSES}
  validates :email_body_editor, inclusion: {in: EmailTemplate::BODY_EDITORS}
  validates_same_workspace :email_template, :email_layout

  scope :ordered, -> { order(created_at: :desc, id: :desc) }

  def email_content
    Marketing::EmailContent.from_campaign(self)
  end

  def email_content_present?
    email_content.present?
  end

  def effective_email_body_editor
    email_content.effective_body_editor
  end

  def utm_params
    {
      utm_source: utm_source,
      utm_medium: utm_medium,
      utm_campaign: utm_campaign,
      utm_term: utm_term,
      utm_content: utm_content
    }.compact
  end
end
