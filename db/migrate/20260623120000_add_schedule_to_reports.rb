class AddScheduleToReports < ActiveRecord::Migration[8.1]
  def change
    add_column :reports, :schedule, :string, null: false, default: "none"
    add_column :reports, :last_sent_at, :datetime
  end
end
