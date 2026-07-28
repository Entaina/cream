class AddMetadataToBookings < ActiveRecord::Migration[8.1]
  def change
    add_column :bookings, :metadata, :jsonb, null: false, default: {}
  end
end
