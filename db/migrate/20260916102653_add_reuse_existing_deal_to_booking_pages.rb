class AddReuseExistingDealToBookingPages < ActiveRecord::Migration[8.1]
  def change
    add_column :booking_pages, :reuse_existing_deal, :boolean, null: false, default: true
  end
end
