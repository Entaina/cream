class StripeSyncJob < ApplicationJob
  queue_as :default

  def perform(connection_id)
    connection = StripeConnection.find_by(id: connection_id)
    return unless connection

    result = StripeSyncService.new(connection: connection).sync!
    Rails.logger.info("StripeSyncJob connection=#{connection_id} result=#{result}")
  end
end
