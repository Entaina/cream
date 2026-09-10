class BeehiivSyncSchedulerJob < ApplicationJob
  queue_as :default

  def perform
    BeehiivConnection.where(sync_enabled: true).includes(:beehiiv_publications).find_each do |connection|
      next unless connection.connected?

      connection.beehiiv_publications.find_each do |publication|
        BeehiivSyncJob.perform_later(publication.id)
      end
    end
  end
end
