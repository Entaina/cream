class BeehiivSyncSchedulerJob < ApplicationJob
  queue_as :default

  def perform
    BeehiivConnection.where(sync_enabled: true).find_each do |connection|
      next unless connection.connected?

      BeehiivSyncJob.perform_later(connection.id)
    end
  end
end
