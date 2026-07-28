# Development uses solid_cable on the primary database so that broadcasts from
# the separate bin/jobs process reach browsers connected to Puma (the async
# adapter is in-process only). Production keeps its dedicated cable database,
# where this table already exists — hence the guard.
class CreateSolidCableMessagesInPrimary < ActiveRecord::Migration[8.0]
  def change
    return if table_exists?(:solid_cable_messages)

    create_table :solid_cable_messages do |t|
      t.binary :channel, limit: 1024, null: false
      t.binary :payload, limit: 536_870_912, null: false
      t.datetime :created_at, null: false
      t.integer :channel_hash, limit: 8, null: false

      t.index :channel
      t.index :channel_hash
      t.index :created_at
    end
  end
end
