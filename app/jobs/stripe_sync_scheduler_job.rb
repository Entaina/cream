class StripeSyncSchedulerJob < ApplicationJob
  queue_as :default

  def perform
    StripeConnection.where(sync_enabled: true).find_each do |connection|
      next unless connection.connected?

      StripeSyncJob.perform_later(connection.id)
    end
  end
end
