class CampaignSend < ApplicationRecord
  STATUSES = %w[pending scheduled sending sent failed cancelled].freeze
  DELIVERY_MODES = %w[email journey both].freeze

  belongs_to :workspace
  belongs_to :campaign
  belongs_to :segment
  belongs_to :email_template, optional: true
  belongs_to :journey, optional: true
  belongs_to :user
  belongs_to :subscription_type, optional: true
  has_many :campaign_variants, dependent: :destroy

  validates :status, inclusion: {in: STATUSES}
  validates :delivery_mode, inclusion: {in: DELIVERY_MODES}
  validate :journey_required_for_journey_delivery

  def sends_email?
    delivery_mode.in?(%w[email both])
  end

  def enrolls_in_journey?
    delivery_mode.in?(%w[journey both])
  end

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

  private

  def journey_required_for_journey_delivery
    return unless enrolls_in_journey?
    return if journey_id.present?

    errors.add(:journey, "must be present for journey delivery")
  end
end
