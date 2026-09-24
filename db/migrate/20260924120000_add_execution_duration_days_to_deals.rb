class AddExecutionDurationDaysToDeals < ActiveRecord::Migration[8.0]
  def change
    add_column :deals, :execution_duration_days, :integer
  end
end
