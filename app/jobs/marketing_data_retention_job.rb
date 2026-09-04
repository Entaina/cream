class MarketingDataRetentionJob < ApplicationJob
  queue_as :default

  RETENTION_DAYS = ENV.fetch("MARKETING_DATA_RETENTION_DAYS", 180).to_i

  def perform
    cutoff = RETENTION_DAYS.days.ago
    PageView.where("occurred_at < ?", cutoff).delete_all
    EmailEvent.where("occurred_at < ?", cutoff).delete_all
  end
end
