class AddSalesDirectorBriefingEnabledToMemberships < ActiveRecord::Migration[8.0]
  def change
    add_column :memberships, :sales_director_briefing_enabled, :boolean, null: false, default: true
  end
end
