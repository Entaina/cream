class Campaign < ApplicationRecord
  STATUSES = %w[draft scheduled sending sent].freeze

  belongs_to :workspace
  has_many :campaign_sends, dependent: :destroy
  has_many :email_messages, dependent: :nullify
  has_many :lead_submissions, dependent: :nullify
  has_many :bookings, dependent: :nullify
  has_many :deals, dependent: :nullify

  validates :name, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :ordered, -> { order(created_at: :desc, id: :desc) }

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
