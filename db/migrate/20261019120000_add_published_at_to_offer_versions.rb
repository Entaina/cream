class AddPublishedAtToOfferVersions < ActiveRecord::Migration[8.1]
  def up
    add_column :offer_versions, :published_at, :datetime
    # Versions that already exist were visible to clients: keep them that way.
    execute "UPDATE offer_versions SET published_at = created_at"
  end

  def down
    remove_column :offer_versions, :published_at
  end
end
