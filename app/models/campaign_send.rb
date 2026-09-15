class CampaignSend < ApplicationRecord
  STATUSES = %w[pending scheduled sending sent failed cancelled].freeze

  belongs_to :workspace
  belongs_to :campaign
  belongs_to :segment
  belongs_to :email_template, optional: true
  belongs_to :user
  belongs_to :subscription_type, optional: true
  has_many :campaign_variants, dependent: :destroy

  validates :status, inclusion: {in: STATUSES}

  def mark_started!
    update!(status: "sending", started_at: Time.current)
  end

  def mark_completed!(stats: {})
    update!(status: "sent", completed_at: Time.current, stats: self.stats.merge(stats.stringify_keys))
  end

  def mark_failed!(stats: {})
    update!(status: "failed", completed_at: Time.current, stats: self.stats.merge(stats.stringify_keys))
  end

  def mark_scheduled!
    update!(status: "scheduled")
  end

  def cancel!
    update!(status: "cancelled", completed_at: Time.current)
  end
end
