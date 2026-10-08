class GmailSyncJob < ApplicationJob
  queue_as :gmail_sync

  def perform(connection_id)
    connection = GmailConnection.find_by(id: connection_id)
    return unless connection

    result = GmailSyncService.new(connection: connection).sync!
    Rails.logger.info("GmailSyncJob connection=#{connection_id} result=#{result}")
  rescue ActiveRecord::RecordNotFound
    nil
  end
end
