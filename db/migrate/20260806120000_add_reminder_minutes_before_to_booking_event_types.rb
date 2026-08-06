class AddReminderMinutesBeforeToBookingEventTypes < ActiveRecord::Migration[8.0]
  def change
    add_column :booking_event_types, :reminder_minutes_before, :integer, default: 60, null: true
  end
end
