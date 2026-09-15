class CreateBeehiivPublications < ActiveRecord::Migration[8.1]
  def up
    create_table :beehiiv_publications do |t|
      t.references :beehiiv_connection, null: false, foreign_key: true
      t.references :subscription_type, null: false, foreign_key: true
      t.string :publication_id, null: false
      t.string :webhook_token, null: false
      t.string :webhook_signing_secret
      t.datetime :last_synced_at
      t.text :last_error
      t.timestamps
    end

    add_index :beehiiv_publications, :webhook_token, unique: true
    add_index :beehiiv_publications,
      [:beehiiv_connection_id, :publication_id],
      unique: true,
      name: "idx_beehiiv_pubs_connection_publication"
    add_index :beehiiv_publications,
      [:beehiiv_connection_id, :subscription_type_id],
      unique: true,
      name: "idx_beehiiv_pubs_connection_subscription_type"

    backfill_beehiiv_publications

    remove_index :beehiiv_connections, :webhook_token
    remove_column :beehiiv_connections, :publication_id
    remove_column :beehiiv_connections, :webhook_signing_secret
    remove_column :beehiiv_connections, :webhook_token
  end

  def down
    add_column :beehiiv_connections, :publication_id, :string
    add_column :beehiiv_connections, :webhook_signing_secret, :string
    add_column :beehiiv_connections, :webhook_token, :string
    add_index :beehiiv_connections, :webhook_token, unique: true

    restore_beehiiv_connections_from_publications

    drop_table :beehiiv_publications
  end

  private

  def backfill_beehiiv_publications
    say_with_time "Backfilling beehiiv_publications from beehiiv_connections" do
      BeehiivConnection.reset_column_information

      BeehiivConnection.find_each do |connection|
        workspace = Workspace.find(connection.workspace_id)
        SubscriptionType.ensure_defaults!(workspace)
        newsletter_type = workspace.subscription_types.find_by!(slug: "newsletter")

        BeehiivPublication.create!(
          beehiiv_connection: connection,
          subscription_type: newsletter_type,
          publication_id: connection.publication_id,
          webhook_token: connection.webhook_token,
          webhook_signing_secret: connection.webhook_signing_secret,
          last_synced_at: connection.last_synced_at,
          last_error: connection.last_error,
          created_at: connection.created_at,
          updated_at: connection.updated_at
        )
      end
    end
  end

  def restore_beehiiv_connections_from_publications
    say_with_time "Restoring beehiiv_connections from newsletter publications" do
      BeehiivConnection.reset_column_information

      BeehiivPublication.includes(:beehiiv_connection, :subscription_type).find_each do |publication|
        next unless publication.subscription_type.slug == "newsletter"

        connection = publication.beehiiv_connection
        connection.update!(
          publication_id: publication.publication_id,
          webhook_token: publication.webhook_token,
          webhook_signing_secret: publication.webhook_signing_secret,
          last_synced_at: publication.last_synced_at,
          last_error: publication.last_error
        )
      end
    end
  end
end
