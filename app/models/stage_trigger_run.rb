class StageTriggerRun < ApplicationRecord
  STATUSES = %w[pending running succeeded failed].freeze

  belongs_to :workspace
  belongs_to :stage_trigger
  belongs_to :deal
  belongs_to :user, optional: true

  validates :status, inclusion: {in: STATUSES}

  scope :recent_first, -> { order(created_at: :desc) }
  scope :with_panel, -> { where.not(panel_markdown: nil) }

  def self.latest_panel_for(deal)
    where(deal: deal).with_panel.recent_first.first
  end

  def start! = update!(status: "running", started_at: Time.current)
  def succeed! = update!(status: "succeeded", finished_at: Time.current)

  def fail!(message)
    update!(status: "failed", error: message.to_s.truncate(2000), finished_at: Time.current)
  end

  def duration
    return unless started_at && finished_at

    finished_at - started_at
  end
end
