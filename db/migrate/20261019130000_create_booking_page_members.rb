class CreateBookingPageMembers < ActiveRecord::Migration[8.1]
  def change
    create_table :booking_page_members do |t|
      t.references :booking_page, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.jsonb :calendar_ids, null: false, default: []

      t.timestamps
    end

    add_index :booking_page_members, %i[booking_page_id user_id], unique: true
  end
end
