class AddGoogleIcalUidToBookings < ActiveRecord::Migration[8.0]
  def change
    add_column :bookings, :google_ical_uid, :string
  end
end
