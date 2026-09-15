class CreateCalendarBooking < ActiveRecord::Migration[8.1]
  def change
    create_table :calendar_connections do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :email
      t.text :access_token
      t.text :refresh_token
      t.datetime :expires_at
      t.text :granted_scopes
      t.timestamps
    end
    add_index :calendar_connections, %i[workspace_id user_id], unique: true

    create_table :booking_pages do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :host, null: false, foreign_key: {to_table: :users}
      t.references :pipeline, null: false, foreign_key: true
      t.string :name, null: false
      t.string :slug, null: false
      t.text :welcome_message
      t.string :avatar_url
      t.string :logo_url
      t.string :timezone, null: false, default: "Europe/Madrid"
      t.jsonb :calendar_ids, null: false, default: ["primary"]
      t.integer :booking_window_days, null: false, default: 60
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :booking_pages, :slug, unique: true

    create_table :booking_event_types do |t|
      t.references :booking_page, null: false, foreign_key: true
      t.string :slug, null: false
      t.jsonb :name_i18n, null: false, default: {}
      t.jsonb :description_i18n, null: false, default: {}
      t.integer :duration_minutes, null: false
      t.string :color, null: false, default: "hoki"
      t.string :location_type, null: false, default: "google_meet"
      t.string :location_address
      t.jsonb :weekly_hours, null: false, default: {}
      t.integer :buffer_before_minutes, null: false, default: 0
      t.integer :buffer_after_minutes, null: false, default: 0
      t.integer :slot_increment_minutes, null: false, default: 15
      t.integer :min_notice_hours, null: false, default: 4
      t.boolean :visible, null: false, default: true
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :booking_event_types, %i[booking_page_id slug], unique: true

    create_table :bookings do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :booking_page, null: false, foreign_key: true
      t.references :booking_event_type, null: false, foreign_key: true
      t.references :person, foreign_key: true
      t.references :deal, foreign_key: true
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email, null: false
      t.string :phone
      t.text :message
      t.jsonb :guest_emails, null: false, default: []
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.string :timezone, null: false
      t.string :google_event_id
      t.string :google_event_link
      t.string :meet_link
      t.string :status, null: false, default: "confirmed"
      t.timestamps
    end
    add_index :bookings, %i[booking_page_id starts_at]
    add_index :bookings, :email
  end
end
