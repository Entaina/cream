class BeehiivSyncJob < ApplicationJob
  queue_as :default

  def perform(connection_id)
    connection = BeehiivConnection.find(connection_id)
    return unless connection.connected?
    return unless connection.sync_enabled?

    client = Marketing::Beehiiv::Client.new(connection)
    cursor = nil

    loop do
      response = client.list_subscriptions(cursor: cursor, limit: 100, expand: [ "custom_fields" ])
      Array(response["data"]).each do |record|
        Marketing::Beehiiv::SubscriberSync.apply!(
          connection: connection,
          record: record,
          source: "beehiiv:sync"
        )
      end

      break unless response["has_more"]

      cursor = response["next_cursor"]
      break if cursor.blank?
    end

    connection.update!(last_synced_at: Time.current, last_error: nil)
  rescue StandardError => e
    connection.update!(last_error: e.message)
    raise
  end
end
