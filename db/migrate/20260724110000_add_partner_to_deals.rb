class AddPartnerToDeals < ActiveRecord::Migration[8.0]
  def change
    add_reference :deals, :partner, null: true, foreign_key: {to_table: :companies}
  end
end
