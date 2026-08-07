class AddEmailTemplateToBookingEventTypes < ActiveRecord::Migration[8.1]
  def change
    add_reference :booking_event_types, :email_template, null: true, foreign_key: { on_delete: :nullify }
  end
end
