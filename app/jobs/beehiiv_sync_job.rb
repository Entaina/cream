class BeehiivSyncJob < ApplicationJob
  queue_as :default

  def perform(publication_id)
    publication = BeehiivPublication.find(publication_id)
    connection = publication.beehiiv_connection
    return unless connection.connected?
    return unless connection.sync_enabled?

    client = Marketing::Beehiiv::Client.new(publication)
    cursor = nil

    loop do
      response = client.list_subscriptions(cursor: cursor, limit: 100, expand: [ "custom_fields" ])
      Array(response["data"]).each do |record|
        Marketing::Beehiiv::SubscriberSync.apply!(
          publication: publication,
          record: record,
          source: "beehiiv:sync"
        )
      end

      break unless response["has_more"]

      cursor = response["next_cursor"]
      break if cursor.blank?
    end

    publication.update!(last_synced_at: Time.current, last_error: nil)
    connection.update!(last_synced_at: Time.current, last_error: nil)
  rescue StandardError => e
    publication.update!(last_error: e.message)
    connection.update!(last_error: e.message)
    raise
  end
end
