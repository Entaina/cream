class AddConfirmationMessageI18nToBookingEventTypes < ActiveRecord::Migration[8.1]
  def change
    add_column :booking_event_types, :confirmation_message_i18n, :jsonb, default: {}, null: false
  end
end
