class AddSuccessTemplateToBookings < ActiveRecord::Migration[8.0]
  def change
    add_reference :booking_pages, :success_template, foreign_key: {to_table: :lead_form_templates}, null: true
    add_reference :booking_event_types, :success_template, foreign_key: {to_table: :lead_form_templates}, null: true
  end
end
