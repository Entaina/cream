class AddCrmAssociationToBookingPages < ActiveRecord::Migration[8.1]
  def change
    add_column :booking_pages, :crm_association, :string, null: false, default: "deal"
    change_column_null :booking_pages, :pipeline_id, true
  end
end
