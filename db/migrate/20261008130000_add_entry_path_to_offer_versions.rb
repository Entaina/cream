class AddEntryPathToOfferVersions < ActiveRecord::Migration[8.1]
  def change
    add_column :offer_versions, :entry_path, :string
  end
end
