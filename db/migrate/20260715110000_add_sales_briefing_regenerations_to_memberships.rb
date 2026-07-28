class AddSalesBriefingRegenerationsToMemberships < ActiveRecord::Migration[8.0]
  def change
    add_column :memberships, :sales_briefing_regenerations_count, :integer, default: 0, null: false
    add_column :memberships, :sales_briefing_regenerations_on, :date
  end
end
