class GmailSyncSchedulerJob < ApplicationJob
  queue_as :default

  def perform
    GmailConnection.where(sync_enabled: true).find_each do |connection|
      next unless connection.connected?
      next unless connection.can_read_metadata?

      GmailSyncJob.perform_later(connection.id)
    end
  end
end
