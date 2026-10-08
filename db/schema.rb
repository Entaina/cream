# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_08_130000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "activities", force: :cascade do |t|
    t.string "action", null: false
    t.datetime "created_at", null: false
    t.jsonb "metadata", default: {}, null: false
    t.bigint "subject_id", null: false
    t.string "subject_type", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.bigint "workspace_id", null: false
    t.index ["subject_type", "subject_id"], name: "index_activities_on_subject"
    t.index ["user_id"], name: "index_activities_on_user_id"
    t.index ["workspace_id", "created_at"], name: "index_activities_on_workspace_id_and_created_at"
    t.index ["workspace_id"], name: "index_activities_on_workspace_id"
  end

  create_table "alert_conditions", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "alert_rule_id", null: false
    t.string "field", null: false
    t.string "operator", default: "eq", null: false
    t.string "compare_value"
    t.boolean "active", default: true, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["alert_rule_id"], name: "index_alert_conditions_on_alert_rule_id"
    t.index ["workspace_id"], name: "index_alert_conditions_on_workspace_id"
  end

  create_table "alert_deliveries", force: :cascade do |t|
    t.bigint "alert_rule_id", null: false
    t.bigint "deal_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["alert_rule_id", "deal_id", "user_id"], name: "idx_on_alert_rule_id_deal_id_user_id_5c7d586558", unique: true
    t.index ["alert_rule_id"], name: "index_alert_deliveries_on_alert_rule_id"
    t.index ["deal_id"], name: "index_alert_deliveries_on_deal_id"
    t.index ["user_id"], name: "index_alert_deliveries_on_user_id"
  end

  create_table "alert_rules", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.string "name", null: false
    t.string "trigger_field", null: false
    t.integer "offset_days", default: 0, null: false
    t.string "recipient", default: "deal_owner", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["workspace_id"], name: "index_alert_rules_on_workspace_id"
  end

  create_table "api_tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "last_used_at"
    t.string "name", null: false
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "workspace_id", null: false
    t.index ["token_digest"], name: "index_api_tokens_on_token_digest", unique: true
    t.index ["user_id"], name: "index_api_tokens_on_user_id"
    t.index ["workspace_id"], name: "index_api_tokens_on_workspace_id"
  end

  create_table "automations", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.string "name", null: false
    t.string "trigger_event", null: false
    t.jsonb "trigger_conditions", default: {}, null: false
    t.string "action_type", null: false
    t.jsonb "action_params", default: {}, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["workspace_id"], name: "index_automations_on_workspace_id"
  end

  create_table "beehiiv_connections", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "user_id", null: false
    t.string "api_key", null: false
    t.datetime "last_synced_at"
    t.text "last_error"
    t.boolean "sync_enabled", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_beehiiv_connections_on_user_id"
    t.index ["workspace_id"], name: "index_beehiiv_connections_on_workspace_id", unique: true
  end

  create_table "beehiiv_publications", force: :cascade do |t|
    t.bigint "beehiiv_connection_id", null: false
    t.bigint "subscription_type_id", null: false
    t.string "publication_id", null: false
    t.string "webhook_token", null: false
    t.string "webhook_signing_secret"
    t.datetime "last_synced_at"
    t.text "last_error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["beehiiv_connection_id", "publication_id"], name: "idx_beehiiv_pubs_connection_publication", unique: true
    t.index ["beehiiv_connection_id", "subscription_type_id"], name: "idx_beehiiv_pubs_connection_subscription_type", unique: true
    t.index ["beehiiv_connection_id"], name: "index_beehiiv_publications_on_beehiiv_connection_id"
    t.index ["subscription_type_id"], name: "index_beehiiv_publications_on_subscription_type_id"
    t.index ["webhook_token"], name: "index_beehiiv_publications_on_webhook_token", unique: true
  end

  create_table "booking_event_types", force: :cascade do |t|
    t.bigint "booking_page_id", null: false
    t.string "slug", null: false
    t.jsonb "name_i18n", default: {}, null: false
    t.jsonb "description_i18n", default: {}, null: false
    t.integer "duration_minutes", null: false
    t.string "color", default: "hoki", null: false
    t.string "location_type", default: "google_meet", null: false
    t.string "location_address"
    t.jsonb "weekly_hours", default: {}, null: false
    t.integer "buffer_before_minutes", default: 0, null: false
    t.integer "buffer_after_minutes", default: 0, null: false
    t.integer "slot_increment_minutes", default: 15, null: false
    t.integer "min_notice_hours", default: 4, null: false
    t.boolean "visible", default: true, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "reminder_minutes_before", default: 60
    t.bigint "email_template_id"
    t.bigint "success_template_id"
    t.jsonb "confirmation_message_i18n", default: {}, null: false
    t.index ["booking_page_id", "slug"], name: "index_booking_event_types_on_booking_page_id_and_slug", unique: true
    t.index ["booking_page_id"], name: "index_booking_event_types_on_booking_page_id"
    t.index ["email_template_id"], name: "index_booking_event_types_on_email_template_id"
    t.index ["success_template_id"], name: "index_booking_event_types_on_success_template_id"
  end

  create_table "booking_pages", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "host_id", null: false
    t.bigint "pipeline_id", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.text "welcome_message"
    t.string "avatar_url"
    t.string "logo_url"
    t.string "timezone", default: "Europe/Madrid", null: false
    t.jsonb "calendar_ids", default: ["primary"], null: false
    t.integer "booking_window_days", default: 60, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "reuse_existing_deal", default: true, null: false
    t.bigint "success_template_id"
    t.index ["host_id"], name: "index_booking_pages_on_host_id"
    t.index ["pipeline_id"], name: "index_booking_pages_on_pipeline_id"
    t.index ["slug"], name: "index_booking_pages_on_slug", unique: true
    t.index ["success_template_id"], name: "index_booking_pages_on_success_template_id"
    t.index ["workspace_id"], name: "index_booking_pages_on_workspace_id"
  end

  create_table "bookings", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "booking_page_id", null: false
    t.bigint "booking_event_type_id", null: false
    t.bigint "person_id"
    t.bigint "deal_id"
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "email", null: false
    t.string "phone"
    t.text "message"
    t.jsonb "guest_emails", default: [], null: false
    t.datetime "starts_at", null: false
    t.datetime "ends_at", null: false
    t.string "timezone", null: false
    t.string "google_event_id"
    t.string "google_event_link"
    t.string "meet_link"
    t.string "status", default: "confirmed", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "metadata", default: {}, null: false
    t.bigint "campaign_id"
    t.string "google_ical_uid"
    t.index ["booking_event_type_id"], name: "index_bookings_on_booking_event_type_id"
    t.index ["booking_page_id", "starts_at"], name: "index_bookings_on_booking_page_id_and_starts_at"
    t.index ["booking_page_id"], name: "index_bookings_on_booking_page_id"
    t.index ["campaign_id"], name: "index_bookings_on_campaign_id"
    t.index ["deal_id"], name: "index_bookings_on_deal_id"
    t.index ["email"], name: "index_bookings_on_email"
    t.index ["person_id"], name: "index_bookings_on_person_id"
    t.index ["workspace_id"], name: "index_bookings_on_workspace_id"
  end

  create_table "calendar_connections", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "user_id", null: false
    t.string "email"
    t.text "access_token"
    t.text "refresh_token"
    t.datetime "expires_at"
    t.text "granted_scopes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_calendar_connections_on_user_id"
    t.index ["workspace_id", "user_id"], name: "index_calendar_connections_on_workspace_id_and_user_id", unique: true
    t.index ["workspace_id"], name: "index_calendar_connections_on_workspace_id"
  end

  create_table "campaign_sends", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "campaign_id", null: false
    t.bigint "segment_id", null: false
    t.bigint "email_template_id"
    t.bigint "user_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "started_at"
    t.datetime "completed_at"
    t.jsonb "stats", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "subscription_type_id"
    t.datetime "scheduled_at"
    t.bigint "journey_id"
    t.string "delivery_mode", default: "email", null: false
    t.index ["campaign_id"], name: "index_campaign_sends_on_campaign_id"
    t.index ["email_template_id"], name: "index_campaign_sends_on_email_template_id"
    t.index ["journey_id"], name: "index_campaign_sends_on_journey_id"
    t.index ["segment_id"], name: "index_campaign_sends_on_segment_id"
    t.index ["subscription_type_id"], name: "index_campaign_sends_on_subscription_type_id"
    t.index ["user_id"], name: "index_campaign_sends_on_user_id"
    t.index ["workspace_id"], name: "index_campaign_sends_on_workspace_id"
  end

  create_table "campaign_variants", force: :cascade do |t|
    t.bigint "campaign_send_id", null: false
    t.string "name", null: false
    t.string "subject", null: false
    t.text "body", null: false
    t.integer "weight", default: 50, null: false
    t.boolean "winner", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_send_id"], name: "index_campaign_variants_on_campaign_send_id"
  end

  create_table "campaigns", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.string "name", null: false
    t.string "status", default: "draft", null: false
    t.date "starts_on"
    t.text "goal"
    t.string "utm_source"
    t.string "utm_medium"
    t.string "utm_campaign"
    t.string "utm_term"
    t.string "utm_content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "email_template_id"
    t.bigint "email_layout_id"
    t.string "email_subject"
    t.text "email_body"
    t.string "email_body_editor", default: "quill", null: false
    t.index ["email_layout_id"], name: "index_campaigns_on_email_layout_id"
    t.index ["email_template_id"], name: "index_campaigns_on_email_template_id"
    t.index ["workspace_id"], name: "index_campaigns_on_workspace_id"
  end

  create_table "comments", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.string "commentable_type", null: false
    t.bigint "commentable_id", null: false
    t.bigint "user_id", null: false
    t.bigint "parent_id"
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["commentable_type", "commentable_id"], name: "index_comments_on_commentable"
    t.index ["parent_id"], name: "index_comments_on_parent_id"
    t.index ["user_id"], name: "index_comments_on_user_id"
    t.index ["workspace_id"], name: "index_comments_on_workspace_id"
  end

  create_table "companies", force: :cascade do |t|
    t.bigint "annual_revenue"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "domain"
    t.string "employee_range"
    t.string "industry"
    t.string "linkedin_url"
    t.string "location"
    t.string "name", null: false
    t.bigint "owner_id"
    t.string "twitter_url"
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.text "fiscal_information"
    t.index ["owner_id"], name: "index_companies_on_owner_id"
    t.index ["workspace_id", "domain"], name: "index_companies_on_workspace_id_and_domain"
    t.index ["workspace_id", "name"], name: "index_companies_on_workspace_id_and_name"
    t.index ["workspace_id"], name: "index_companies_on_workspace_id"
  end

  create_table "custom_field_values", force: :cascade do |t|
    t.bigint "custom_field_id", null: false
    t.bigint "workspace_id", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.jsonb "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["custom_field_id", "record_type", "record_id"], name: "index_custom_field_values_on_field_and_record", unique: true
    t.index ["custom_field_id"], name: "index_custom_field_values_on_custom_field_id"
    t.index ["record_type", "record_id"], name: "index_custom_field_values_on_record"
    t.index ["record_type", "record_id"], name: "index_custom_field_values_on_record_type_and_record_id"
    t.index ["workspace_id"], name: "index_custom_field_values_on_workspace_id"
  end

  create_table "custom_fields", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.string "record_type", null: false
    t.string "name", null: false
    t.string "key", null: false
    t.string "field_type", null: false
    t.jsonb "options", default: [], null: false
    t.integer "position", default: 0, null: false
    t.boolean "required", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "formula_expression"
    t.string "reference_type"
    t.index ["workspace_id", "record_type", "key"], name: "index_custom_fields_on_workspace_id_and_record_type_and_key", unique: true
    t.index ["workspace_id", "record_type", "position"], name: "idx_on_workspace_id_record_type_position_e95e0d1f7e"
    t.index ["workspace_id"], name: "index_custom_fields_on_workspace_id"
  end

  create_table "deal_accesses", force: :cascade do |t|
    t.bigint "deal_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deal_id", "user_id"], name: "index_deal_accesses_on_deal_id_and_user_id", unique: true
    t.index ["deal_id"], name: "index_deal_accesses_on_deal_id"
    t.index ["user_id"], name: "index_deal_accesses_on_user_id"
  end

  create_table "deal_contacts", force: :cascade do |t|
    t.bigint "deal_id", null: false
    t.bigint "person_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deal_id", "person_id"], name: "index_deal_contacts_on_deal_id_and_person_id", unique: true
    t.index ["deal_id"], name: "index_deal_contacts_on_deal_id"
    t.index ["person_id"], name: "index_deal_contacts_on_person_id"
  end

  create_table "deal_products", force: :cascade do |t|
    t.bigint "deal_id", null: false
    t.bigint "product_id", null: false
    t.integer "quantity", default: 1, null: false
    t.decimal "unit_price", precision: 14, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "edition_id"
    t.index ["deal_id"], name: "index_deal_products_on_deal_id"
    t.index ["edition_id"], name: "index_deal_products_on_edition_id"
    t.index ["product_id"], name: "index_deal_products_on_product_id"
  end

  create_table "deals", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "EUR", null: false
    t.date "expected_close_date"
    t.string "name", null: false
    t.bigint "owner_id"
    t.integer "position", default: 0, null: false
    t.integer "probability", default: 0
    t.datetime "updated_at", null: false
    t.decimal "value", precision: 14, scale: 2, default: "0.0"
    t.bigint "workspace_id", null: false
    t.bigint "pipeline_id", null: false
    t.bigint "pipeline_stage_id", null: false
    t.bigint "partner_id"
    t.string "invoice_number"
    t.bigint "campaign_id"
    t.integer "execution_duration_days"
    t.date "execution_starts_on"
    t.date "execution_ends_on"
    t.string "payment_method"
    t.date "payment_on"
    t.index ["campaign_id"], name: "index_deals_on_campaign_id"
    t.index ["company_id"], name: "index_deals_on_company_id"
    t.index ["owner_id"], name: "index_deals_on_owner_id"
    t.index ["partner_id"], name: "index_deals_on_partner_id"
    t.index ["pipeline_id"], name: "index_deals_on_pipeline_id"
    t.index ["pipeline_stage_id"], name: "index_deals_on_pipeline_stage_id"
    t.index ["workspace_id", "invoice_number"], name: "index_deals_on_workspace_id_and_invoice_number"
    t.index ["workspace_id", "pipeline_stage_id", "position"], name: "index_deals_on_workspace_id_and_pipeline_stage_id_and_position"
    t.index ["workspace_id"], name: "index_deals_on_workspace_id"
  end

  create_table "editions", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "starts_on"
    t.date "ends_on"
    t.bigint "product_id", null: false
    t.index ["product_id", "name"], name: "index_editions_on_product_id_and_name", unique: true
    t.index ["product_id"], name: "index_editions_on_product_id"
    t.index ["workspace_id"], name: "index_editions_on_workspace_id"
  end

  create_table "email_events", force: :cascade do |t|
    t.bigint "email_message_id", null: false
    t.string "event_type", null: false
    t.string "url"
    t.datetime "occurred_at", null: false
    t.jsonb "payload", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_message_id", "event_type", "occurred_at"], name: "idx_email_events_message_type_at"
    t.index ["email_message_id"], name: "index_email_events_on_email_message_id"
    t.index ["occurred_at"], name: "index_email_events_on_occurred_at"
  end

  create_table "email_layouts", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.string "name", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["workspace_id"], name: "index_email_layouts_on_workspace_id"
  end

  create_table "email_messages", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "user_id", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.string "to_address", null: false
    t.string "subject", null: false
    t.text "body", null: false
    t.string "status", default: "sent", null: false
    t.string "tracking_token"
    t.datetime "opened_at"
    t.integer "clicks_count", default: 0, null: false
    t.string "mail_merge_batch_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "scheduled_at"
    t.datetime "follow_up_at"
    t.datetime "replied_at"
    t.string "gmail_message_id"
    t.string "gmail_thread_id"
    t.string "rfc822_message_id"
    t.string "direction", default: "outbound", null: false
    t.string "from_address"
    t.bigint "in_reply_to_id"
    t.bigint "campaign_id"
    t.boolean "marketing_send", default: false, null: false
    t.bigint "campaign_variant_id"
    t.string "esp_message_id"
    t.index ["campaign_id"], name: "index_email_messages_on_campaign_id"
    t.index ["campaign_variant_id"], name: "index_email_messages_on_campaign_variant_id"
    t.index ["direction"], name: "index_email_messages_on_direction"
    t.index ["esp_message_id"], name: "index_email_messages_on_esp_message_id"
    t.index ["follow_up_at"], name: "index_email_messages_on_follow_up_at"
    t.index ["gmail_message_id"], name: "index_email_messages_on_gmail_message_id"
    t.index ["gmail_thread_id"], name: "index_email_messages_on_gmail_thread_id"
    t.index ["in_reply_to_id"], name: "index_email_messages_on_in_reply_to_id"
    t.index ["record_type", "record_id"], name: "index_email_messages_on_record"
    t.index ["rfc822_message_id"], name: "index_email_messages_on_rfc822_message_id"
    t.index ["scheduled_at"], name: "index_email_messages_on_scheduled_at"
    t.index ["tracking_token"], name: "index_email_messages_on_tracking_token", unique: true
    t.index ["user_id"], name: "index_email_messages_on_user_id"
    t.index ["workspace_id"], name: "index_email_messages_on_workspace_id"
  end

  create_table "email_subscriptions", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "person_id", null: false
    t.bigint "subscription_type_id", null: false
    t.string "status", default: "subscribed", null: false
    t.datetime "opted_in_at"
    t.datetime "opted_out_at"
    t.string "source"
    t.string "legal_basis"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "beehiiv_subscription_id"
    t.index ["person_id", "subscription_type_id"], name: "idx_email_subscriptions_person_type", unique: true
    t.index ["person_id"], name: "index_email_subscriptions_on_person_id"
    t.index ["subscription_type_id"], name: "index_email_subscriptions_on_subscription_type_id"
    t.index ["workspace_id", "beehiiv_subscription_id"], name: "idx_email_subscriptions_workspace_beehiiv_sub", unique: true, where: "(beehiiv_subscription_id IS NOT NULL)"
    t.index ["workspace_id"], name: "index_email_subscriptions_on_workspace_id"
  end

  create_table "email_suppressions", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.string "address", null: false
    t.string "reason", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["workspace_id", "address"], name: "index_email_suppressions_on_workspace_id_and_address", unique: true
    t.index ["workspace_id"], name: "index_email_suppressions_on_workspace_id"
  end

  create_table "email_templates", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.string "subject"
    t.text "body", null: false
    t.boolean "shared", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "key"
    t.bigint "email_layout_id"
    t.string "body_editor", default: "quill", null: false
    t.index ["email_layout_id"], name: "index_email_templates_on_email_layout_id"
    t.index ["user_id"], name: "index_email_templates_on_user_id"
    t.index ["workspace_id", "key"], name: "index_email_templates_on_workspace_id_and_key", unique: true, where: "(key IS NOT NULL)"
    t.index ["workspace_id"], name: "index_email_templates_on_workspace_id"
  end

  create_table "gmail_connections", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "user_id", null: false
    t.text "access_token"
    t.text "refresh_token"
    t.datetime "expires_at"
    t.boolean "sync_enabled", default: false, null: false
    t.datetime "last_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "email"
    t.boolean "send_enabled", default: false, null: false
    t.text "granted_scopes"
    t.index ["user_id"], name: "index_gmail_connections_on_user_id"
    t.index ["workspace_id", "user_id"], name: "index_gmail_connections_on_workspace_id_and_user_id", unique: true
    t.index ["workspace_id"], name: "index_gmail_connections_on_workspace_id"
  end

  create_table "invitations", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.string "email_address", null: false
    t.string "role", default: "salesperson", null: false
    t.string "token_digest", null: false
    t.bigint "invited_by_id", null: false
    t.datetime "accepted_at"
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["invited_by_id"], name: "index_invitations_on_invited_by_id"
    t.index ["token_digest"], name: "index_invitations_on_token_digest", unique: true
    t.index ["workspace_id", "email_address"], name: "index_invitations_pending_on_workspace_and_email", unique: true, where: "(accepted_at IS NULL)"
    t.index ["workspace_id"], name: "index_invitations_on_workspace_id"
  end

  create_table "journey_enrollments", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "journey_id", null: false
    t.bigint "person_id", null: false
    t.bigint "current_step_id"
    t.string "state", default: "active", null: false
    t.datetime "next_run_at"
    t.datetime "enrolled_at", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["current_step_id"], name: "index_journey_enrollments_on_current_step_id"
    t.index ["journey_id", "person_id", "state"], name: "idx_journey_enrollments_journey_person_state"
    t.index ["journey_id"], name: "index_journey_enrollments_on_journey_id"
    t.index ["person_id"], name: "index_journey_enrollments_on_person_id"
    t.index ["state", "next_run_at"], name: "idx_journey_enrollments_due"
    t.index ["workspace_id"], name: "index_journey_enrollments_on_workspace_id"
  end

  create_table "journey_steps", force: :cascade do |t|
    t.bigint "journey_id", null: false
    t.integer "position", default: 0, null: false
    t.string "step_type", null: false
    t.jsonb "config", default: {}, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["journey_id", "position"], name: "index_journey_steps_on_journey_id_and_position"
    t.index ["journey_id"], name: "index_journey_steps_on_journey_id"
  end

  create_table "journeys", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.string "name", null: false
    t.boolean "active", default: true, null: false
    t.string "entry_trigger", null: false
    t.jsonb "entry_config", default: {}, null: false
    t.integer "max_reenrollments", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "product_id"
    t.boolean "stop_on_open_deal", default: false, null: false
    t.index ["product_id"], name: "index_journeys_on_product_id"
    t.index ["workspace_id"], name: "index_journeys_on_workspace_id"
  end

  create_table "lead_form_templates", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.string "path", null: false
    t.boolean "partial", default: false, null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "submission_schema", default: {}, null: false
    t.string "page_slug"
    t.string "kind", default: "form", null: false
    t.index ["kind"], name: "index_lead_form_templates_on_kind"
    t.index ["workspace_id", "page_slug"], name: "index_lead_form_templates_on_workspace_id_and_page_slug", unique: true, where: "(page_slug IS NOT NULL)"
    t.index ["workspace_id", "path"], name: "index_lead_form_templates_on_workspace_id_and_path", unique: true
    t.index ["workspace_id"], name: "index_lead_form_templates_on_workspace_id"
  end

  create_table "lead_forms", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "pipeline_id"
    t.bigint "responsible_id", null: false
    t.bigint "email_template_id"
    t.string "name", null: false
    t.string "slug", null: false
    t.string "template_key", null: false
    t.boolean "collects_company", default: false, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "pipeline_routes", default: {}, null: false
    t.string "success_redirect_url"
    t.jsonb "hidden_field_keys", default: [], null: false
    t.bigint "pipeline_stage_id"
    t.string "first_task_title", default: "Contactar lead", null: false
    t.integer "first_task_due_days", default: 1, null: false
    t.bigint "product_id"
    t.string "destination", default: "deal", null: false
    t.bigint "subscription_type_id"
    t.text "marketing_consent_text"
    t.boolean "require_corporate_email", default: false, null: false
    t.index ["email_template_id"], name: "index_lead_forms_on_email_template_id"
    t.index ["pipeline_id"], name: "index_lead_forms_on_pipeline_id"
    t.index ["pipeline_stage_id"], name: "index_lead_forms_on_pipeline_stage_id"
    t.index ["product_id"], name: "index_lead_forms_on_product_id"
    t.index ["responsible_id"], name: "index_lead_forms_on_responsible_id"
    t.index ["slug"], name: "index_lead_forms_on_slug", unique: true
    t.index ["subscription_type_id"], name: "index_lead_forms_on_subscription_type_id"
    t.index ["workspace_id"], name: "index_lead_forms_on_workspace_id"
  end

  create_table "lead_submissions", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "lead_form_id", null: false
    t.bigint "deal_id"
    t.bigint "person_id", null: false
    t.jsonb "data", default: {}, null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "campaign_id"
    t.string "capture_destination", default: "deal", null: false
    t.string "submission_key"
    t.bigint "privacy_policy_version_id"
    t.index ["campaign_id"], name: "index_lead_submissions_on_campaign_id"
    t.index ["deal_id"], name: "index_lead_submissions_on_deal_id"
    t.index ["lead_form_id"], name: "index_lead_submissions_on_lead_form_id"
    t.index ["person_id"], name: "index_lead_submissions_on_person_id"
    t.index ["privacy_policy_version_id"], name: "index_lead_submissions_on_privacy_policy_version_id"
    t.index ["workspace_id", "lead_form_id", "person_id", "created_at"], name: "index_lead_submissions_on_form_person_created"
    t.index ["workspace_id", "lead_form_id", "submission_key"], name: "index_lead_submissions_on_form_submission_key", unique: true, where: "(submission_key IS NOT NULL)"
    t.index ["workspace_id", "person_id", "created_at"], name: "index_lead_submissions_on_person_created"
    t.index ["workspace_id"], name: "index_lead_submissions_on_workspace_id"
  end

  create_table "list_entries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "list_id", null: false
    t.integer "position", default: 0, null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["list_id", "record_type", "record_id"], name: "index_list_entries_on_list_id_and_record_type_and_record_id", unique: true
    t.index ["list_id"], name: "index_list_entries_on_list_id"
    t.index ["record_type", "record_id"], name: "index_list_entries_on_record"
  end

  create_table "list_filter_states", force: :cascade do |t|
    t.bigint "session_id", null: false
    t.bigint "workspace_id", null: false
    t.string "key", null: false
    t.jsonb "params", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["session_id", "workspace_id", "key"], name: "idx_on_session_id_workspace_id_key_a88bc6860f", unique: true
    t.index ["session_id"], name: "index_list_filter_states_on_session_id"
    t.index ["workspace_id"], name: "index_list_filter_states_on_workspace_id"
  end

  create_table "lists", force: :cascade do |t|
    t.string "color", default: "blue", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["workspace_id"], name: "index_lists_on_workspace_id"
  end

  create_table "llmemory_categories", force: :cascade do |t|
    t.string "user_id", null: false
    t.string "category_name", null: false
    t.text "content", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "category_name"], name: "index_llmemory_categories_on_user_id_and_category_name", unique: true
  end

  create_table "llmemory_checkpoints", force: :cascade do |t|
    t.string "user_id", null: false
    t.string "session_id", null: false
    t.jsonb "state", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "session_id"], name: "index_llmemory_checkpoints_on_user_id_and_session_id", unique: true
  end

  create_table "llmemory_edges", force: :cascade do |t|
    t.string "user_id", null: false
    t.bigint "subject_id", null: false
    t.string "predicate", null: false
    t.bigint "object_id", null: false
    t.jsonb "properties", default: {}
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["object_id"], name: "index_llmemory_edges_on_object_id"
    t.index ["subject_id"], name: "index_llmemory_edges_on_subject_id"
    t.index ["user_id", "subject_id", "predicate"], name: "index_llmemory_edges_on_user_id_and_subject_id_and_predicate"
  end

  create_table "llmemory_embeddings", force: :cascade do |t|
    t.string "user_id", null: false
    t.string "source_type", null: false
    t.string "source_id", null: false
    t.vector "embedding", limit: 1536
    t.text "text_content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "source_type", "source_id"], name: "idx_on_user_id_source_type_source_id_df6fe1cd95", unique: true
  end

  create_table "llmemory_episodes", id: :string, force: :cascade do |t|
    t.string "user_id", null: false
    t.jsonb "data", default: {}, null: false
    t.text "search_text"
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "search_tokens"
    t.index ["user_id"], name: "index_llmemory_episodes_on_user_id"
  end

  create_table "llmemory_items", id: :string, force: :cascade do |t|
    t.string "user_id", null: false
    t.string "category", null: false
    t.text "content", null: false
    t.string "source_resource_id"
    t.float "importance", default: 0.7
    t.jsonb "provenance"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "search_tokens"
    t.index ["user_id"], name: "index_llmemory_items_on_user_id"
  end

  create_table "llmemory_nodes", force: :cascade do |t|
    t.string "user_id", null: false
    t.string "entity_type", null: false
    t.string "name", null: false
    t.jsonb "properties", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "entity_type", "name"], name: "index_llmemory_nodes_on_user_id_and_entity_type_and_name", unique: true
  end

  create_table "llmemory_resources", id: :string, force: :cascade do |t|
    t.string "user_id", null: false
    t.text "text", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "search_tokens"
    t.index ["user_id"], name: "index_llmemory_resources_on_user_id"
  end

  create_table "llmemory_skills", id: :string, force: :cascade do |t|
    t.string "user_id", null: false
    t.jsonb "data", default: {}, null: false
    t.text "search_text"
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "search_tokens"
    t.text "name_det"
    t.index ["user_id"], name: "index_llmemory_skills_on_user_id"
  end

  create_table "mailjet_connections", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "user_id", null: false
    t.text "api_key"
    t.text "secret_key"
    t.string "from_email"
    t.string "from_name"
    t.string "webhook_token", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "transactional_enabled", default: false, null: false
    t.boolean "sender_domain_validated", default: false, null: false
    t.index ["user_id"], name: "index_mailjet_connections_on_user_id"
    t.index ["webhook_token"], name: "index_mailjet_connections_on_webhook_token", unique: true
    t.index ["workspace_id"], name: "index_mailjet_connections_on_workspace_id", unique: true
  end

  create_table "marketing_product_interests", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "person_id", null: false
    t.bigint "product_id", null: false
    t.bigint "recorded_by_id"
    t.bigint "deal_id"
    t.bigint "converted_by_id"
    t.bigint "lead_submission_id"
    t.string "status", default: "pending", null: false
    t.string "source_kind", default: "manual", null: false
    t.text "description"
    t.text "dismissal_reason"
    t.datetime "occurred_at", null: false
    t.datetime "converted_at"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["converted_by_id"], name: "index_marketing_product_interests_on_converted_by_id"
    t.index ["deal_id"], name: "index_marketing_product_interests_on_deal_id"
    t.index ["lead_submission_id", "product_id"], name: "index_mql_interests_on_submission_product", unique: true, where: "(lead_submission_id IS NOT NULL)"
    t.index ["lead_submission_id"], name: "index_marketing_product_interests_on_lead_submission_id"
    t.index ["person_id"], name: "index_marketing_product_interests_on_person_id"
    t.index ["product_id"], name: "index_marketing_product_interests_on_product_id"
    t.index ["recorded_by_id"], name: "index_marketing_product_interests_on_recorded_by_id"
    t.index ["workspace_id", "person_id", "status"], name: "index_mql_interests_on_ws_person_status"
    t.index ["workspace_id", "product_id", "status", "occurred_at"], name: "index_mql_interests_on_ws_product_status_occurred"
    t.index ["workspace_id"], name: "index_marketing_product_interests_on_workspace_id"
  end

  create_table "memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "role", default: "salesperson", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "workspace_id", null: false
    t.bigint "current_pipeline_id"
    t.boolean "sales_director_briefing_enabled", default: true, null: false
    t.integer "sales_briefing_regenerations_count", default: 0, null: false
    t.date "sales_briefing_regenerations_on"
    t.boolean "alert_in_app", default: true, null: false
    t.boolean "alert_email", default: false, null: false
    t.boolean "superadmin_access", default: false, null: false
    t.index ["current_pipeline_id"], name: "index_memberships_on_current_pipeline_id"
    t.index ["user_id"], name: "index_memberships_on_user_id"
    t.index ["workspace_id", "user_id"], name: "index_memberships_on_workspace_id_and_user_id", unique: true
    t.index ["workspace_id"], name: "index_memberships_on_workspace_id"
  end

  create_table "notes", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.bigint "notable_id", null: false
    t.string "notable_type", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "workspace_id", null: false
    t.index ["notable_type", "notable_id"], name: "index_notes_on_notable"
    t.index ["user_id"], name: "index_notes_on_user_id"
    t.index ["workspace_id"], name: "index_notes_on_workspace_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "user_id", null: false
    t.bigint "actor_id"
    t.string "kind", null: false
    t.string "title", null: false
    t.text "body"
    t.string "url"
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_notifications_on_actor_id"
    t.index ["user_id", "read_at", "created_at"], name: "index_notifications_on_user_id_and_read_at_and_created_at"
    t.index ["user_id"], name: "index_notifications_on_user_id"
    t.index ["workspace_id"], name: "index_notifications_on_workspace_id"
  end

  create_table "oauth_access_grants", force: :cascade do |t|
    t.bigint "application_id", null: false
    t.string "code_challenge"
    t.string "code_challenge_method"
    t.datetime "created_at", null: false
    t.integer "expires_in", null: false
    t.text "redirect_uri", null: false
    t.bigint "resource_owner_id", null: false
    t.datetime "revoked_at"
    t.string "scopes", default: "", null: false
    t.string "token", null: false
    t.index ["application_id"], name: "index_oauth_access_grants_on_application_id"
    t.index ["resource_owner_id"], name: "index_oauth_access_grants_on_resource_owner_id"
    t.index ["token"], name: "index_oauth_access_grants_on_token", unique: true
  end

  create_table "oauth_access_tokens", force: :cascade do |t|
    t.bigint "application_id", null: false
    t.datetime "created_at", null: false
    t.integer "expires_in"
    t.string "previous_refresh_token", default: "", null: false
    t.string "refresh_token"
    t.bigint "resource_owner_id"
    t.datetime "revoked_at"
    t.string "scopes"
    t.string "token", null: false
    t.index ["application_id"], name: "index_oauth_access_tokens_on_application_id"
    t.index ["refresh_token"], name: "index_oauth_access_tokens_on_refresh_token", unique: true
    t.index ["resource_owner_id"], name: "index_oauth_access_tokens_on_resource_owner_id"
    t.index ["token"], name: "index_oauth_access_tokens_on_token", unique: true
  end

  create_table "oauth_applications", force: :cascade do |t|
    t.boolean "confidential", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.text "redirect_uri", null: false
    t.string "scopes", default: "", null: false
    t.string "secret"
    t.string "uid", null: false
    t.datetime "updated_at", null: false
    t.index ["uid"], name: "index_oauth_applications_on_uid", unique: true
  end

  create_table "offer_versions", force: :cascade do |t|
    t.bigint "offer_id", null: false
    t.bigint "user_id", null: false
    t.integer "number", null: false
    t.text "html_body"
    t.text "comment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "entry_path"
    t.index ["offer_id", "number"], name: "index_offer_versions_on_offer_id_and_number", unique: true
    t.index ["offer_id"], name: "index_offer_versions_on_offer_id"
    t.index ["user_id"], name: "index_offer_versions_on_user_id"
  end

  create_table "offers", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "deal_id", null: false
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deal_id"], name: "index_offers_on_deal_id"
    t.index ["user_id"], name: "index_offers_on_user_id"
    t.index ["workspace_id"], name: "index_offers_on_workspace_id"
  end

  create_table "page_views", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "person_id"
    t.string "anonymous_id", null: false
    t.string "url", null: false
    t.string "referrer"
    t.string "utm_source"
    t.string "utm_medium"
    t.string "utm_campaign"
    t.string "utm_term"
    t.string "utm_content"
    t.string "session_id"
    t.datetime "occurred_at", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["person_id"], name: "index_page_views_on_person_id"
    t.index ["workspace_id", "anonymous_id", "occurred_at"], name: "idx_page_views_workspace_anon_at"
    t.index ["workspace_id", "person_id", "occurred_at"], name: "idx_page_views_workspace_person_at"
    t.index ["workspace_id"], name: "index_page_views_on_workspace_id"
  end

  create_table "people", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "email"
    t.string "first_name", default: "", null: false
    t.string "job_title"
    t.string "last_name", default: "", null: false
    t.string "linkedin_url"
    t.string "location"
    t.bigint "owner_id"
    t.string "phone"
    t.string "twitter_url"
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.string "source"
    t.date "first_contact_on"
    t.bigint "brought_by_id"
    t.integer "lead_score", default: 0, null: false
    t.string "lifecycle_stage", default: "subscriber", null: false
    t.datetime "lead_score_decayed_at"
    t.text "internal_notes"
    t.index ["brought_by_id"], name: "index_people_on_brought_by_id"
    t.index ["company_id"], name: "index_people_on_company_id"
    t.index ["owner_id"], name: "index_people_on_owner_id"
    t.index ["workspace_id", "email"], name: "index_people_on_workspace_id_and_email"
    t.index ["workspace_id", "last_name", "first_name"], name: "index_people_on_workspace_id_and_last_name_and_first_name"
    t.index ["workspace_id", "lifecycle_stage"], name: "index_people_on_workspace_id_and_lifecycle_stage"
    t.index ["workspace_id"], name: "index_people_on_workspace_id"
  end

  create_table "person_emails", force: :cascade do |t|
    t.bigint "person_id", null: false
    t.bigint "workspace_id", null: false
    t.string "address", null: false
    t.boolean "primary", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["person_id", "primary"], name: "index_person_emails_on_person_id_and_primary"
    t.index ["person_id"], name: "index_person_emails_on_person_id"
    t.index ["workspace_id", "address"], name: "index_person_emails_on_workspace_id_and_address"
    t.index ["workspace_id"], name: "index_person_emails_on_workspace_id"
  end

  create_table "person_relationships", force: :cascade do |t|
    t.bigint "from_person_id", null: false
    t.bigint "to_person_id", null: false
    t.string "relationship_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["from_person_id", "to_person_id", "relationship_type"], name: "index_person_relationships_on_from_to_type", unique: true
    t.index ["from_person_id"], name: "index_person_relationships_on_from_person_id"
    t.index ["to_person_id"], name: "index_person_relationships_on_to_person_id"
  end

  create_table "pipeline_stages", force: :cascade do |t|
    t.bigint "pipeline_id", null: false
    t.bigint "workspace_id", null: false
    t.string "name", null: false
    t.string "color", default: "chicago", null: false
    t.integer "probability", default: 0, null: false
    t.integer "position", default: 0, null: false
    t.boolean "won", default: false, null: false
    t.boolean "closed", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pipeline_id", "position"], name: "index_pipeline_stages_on_pipeline_id_and_position"
    t.index ["pipeline_id"], name: "index_pipeline_stages_on_pipeline_id"
    t.index ["workspace_id"], name: "index_pipeline_stages_on_workspace_id"
  end

  create_table "pipelines", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.boolean "default_pipeline", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "card_fields", default: ["value", "company", "expected_close_date", "owner"], null: false, array: true
    t.index ["workspace_id"], name: "index_pipelines_on_workspace_id"
  end

  create_table "privacy_policy_versions", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.string "content_hash", null: false
    t.string "policy_path", null: false
    t.text "policy_content", null: false
    t.text "statement_content", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["workspace_id", "content_hash"], name: "index_privacy_policy_versions_on_workspace_id_and_content_hash", unique: true
    t.index ["workspace_id"], name: "index_privacy_policy_versions_on_workspace_id"
  end

  create_table "products", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.string "name", null: false
    t.text "description"
    t.decimal "price", precision: 14, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "segment"
    t.index ["workspace_id", "name"], name: "index_products_on_workspace_id_and_name"
    t.index ["workspace_id"], name: "index_products_on_workspace_id"
  end

  create_table "record_attachments", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.string "attachable_type", null: false
    t.bigint "attachable_id", null: false
    t.bigint "user_id", null: false
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["attachable_type", "attachable_id"], name: "index_record_attachments_on_attachable"
    t.index ["user_id"], name: "index_record_attachments_on_user_id"
    t.index ["workspace_id"], name: "index_record_attachments_on_workspace_id"
  end

  create_table "reports", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.string "record_type", null: false
    t.string "metric", null: false
    t.string "group_by", null: false
    t.string "date_range", default: "all", null: false
    t.boolean "shared", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "schedule", default: "none", null: false
    t.datetime "last_sent_at"
    t.bigint "pipeline_id"
    t.index ["pipeline_id"], name: "index_reports_on_pipeline_id"
    t.index ["user_id"], name: "index_reports_on_user_id"
    t.index ["workspace_id"], name: "index_reports_on_workspace_id"
  end

  create_table "sales_briefings", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.date "briefing_date", null: false
    t.text "summary"
    t.jsonb "items", default: [], null: false
    t.datetime "generated_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.jsonb "wins", default: [], null: false
    t.jsonb "misses", default: [], null: false
    t.index ["user_id"], name: "index_sales_briefings_on_user_id"
    t.index ["workspace_id", "briefing_date"], name: "index_sales_briefings_team_unique", unique: true, where: "(user_id IS NULL)"
    t.index ["workspace_id", "user_id", "briefing_date"], name: "index_sales_briefings_personal_unique", unique: true, where: "(user_id IS NOT NULL)"
    t.index ["workspace_id"], name: "index_sales_briefings_on_workspace_id"
  end

  create_table "saved_views", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "user_id", null: false
    t.string "record_type", null: false
    t.string "name", null: false
    t.jsonb "filters", default: {}, null: false
    t.string "sort"
    t.string "direction", default: "asc", null: false
    t.boolean "shared", default: false, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_saved_views_on_user_id"
    t.index ["workspace_id", "record_type"], name: "index_saved_views_on_workspace_id_and_record_type"
    t.index ["workspace_id"], name: "index_saved_views_on_workspace_id"
  end

  create_table "scoring_rules", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.string "name", null: false
    t.string "event_type"
    t.jsonb "conditions", default: [], null: false
    t.integer "points", default: 0, null: false
    t.integer "decay_days"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["workspace_id"], name: "index_scoring_rules_on_workspace_id"
  end

  create_table "segment_memberships", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "segment_id", null: false
    t.bigint "person_id", null: false
    t.datetime "entered_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["person_id"], name: "index_segment_memberships_on_person_id"
    t.index ["segment_id", "person_id"], name: "index_segment_memberships_on_segment_id_and_person_id", unique: true
    t.index ["segment_id"], name: "index_segment_memberships_on_segment_id"
    t.index ["workspace_id"], name: "index_segment_memberships_on_workspace_id"
  end

  create_table "segments", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.string "record_type", default: "Person", null: false
    t.jsonb "filters", default: {}, null: false
    t.text "description"
    t.boolean "shared", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_segments_on_user_id"
    t.index ["workspace_id"], name: "index_segments_on_workspace_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "slack_integrations", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.string "webhook_url", null: false
    t.boolean "active", default: true, null: false
    t.jsonb "notify_events", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["workspace_id"], name: "index_slack_integrations_on_workspace_id"
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", null: false
    t.binary "payload", null: false
    t.datetime "created_at", null: false
    t.bigint "channel_hash", null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_queue_batch_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "batch_id", null: false
    t.datetime "created_at", null: false
    t.index ["batch_id"], name: "index_solid_queue_batch_executions_on_batch_id"
    t.index ["job_id"], name: "index_solid_queue_batch_executions_on_job_id", unique: true
  end

  create_table "solid_queue_batches", force: :cascade do |t|
    t.string "active_job_batch_id"
    t.string "description"
    t.text "on_finish"
    t.text "on_success"
    t.text "on_failure"
    t.text "metadata"
    t.integer "total_jobs", default: 0, null: false
    t.integer "completed_jobs", default: 0, null: false
    t.integer "failed_jobs", default: 0, null: false
    t.datetime "enqueued_at"
    t.datetime "finished_at"
    t.datetime "failed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_batch_id"], name: "index_solid_queue_batches_on_active_job_batch_id", unique: true
    t.index ["finished_at"], name: "index_solid_queue_batches_on_finished_at"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "batch_id"
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["batch_id"], name: "index_solid_queue_jobs_on_batch_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "stage_conditions", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "pipeline_stage_id", null: false
    t.string "field", null: false
    t.string "operator", default: "eq", null: false
    t.string "compare_value"
    t.boolean "active", default: true, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pipeline_stage_id"], name: "index_stage_conditions_on_pipeline_stage_id"
    t.index ["workspace_id"], name: "index_stage_conditions_on_workspace_id"
  end

  create_table "stage_field_formats", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "pipeline_stage_id", null: false
    t.string "field", null: false
    t.string "operator", default: "eq", null: false
    t.string "compare_value"
    t.string "display_text", null: false
    t.boolean "active", default: true, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pipeline_stage_id", "field"], name: "index_stage_field_formats_on_pipeline_stage_id_and_field"
    t.index ["pipeline_stage_id"], name: "index_stage_field_formats_on_pipeline_stage_id"
    t.index ["workspace_id"], name: "index_stage_field_formats_on_workspace_id"
  end

  create_table "stage_trigger_runs", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "stage_trigger_id", null: false
    t.bigint "deal_id", null: false
    t.bigint "user_id"
    t.string "status", default: "pending", null: false
    t.jsonb "transcript", default: [], null: false
    t.jsonb "ui_actions", default: [], null: false
    t.string "panel_title"
    t.text "panel_markdown"
    t.text "error"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deal_id", "created_at"], name: "index_stage_trigger_runs_on_deal_id_and_created_at"
    t.index ["deal_id"], name: "index_stage_trigger_runs_on_deal_id"
    t.index ["stage_trigger_id"], name: "index_stage_trigger_runs_on_stage_trigger_id"
    t.index ["user_id"], name: "index_stage_trigger_runs_on_user_id"
    t.index ["workspace_id"], name: "index_stage_trigger_runs_on_workspace_id"
  end

  create_table "stage_triggers", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "pipeline_stage_id", null: false
    t.string "name", null: false
    t.text "instructions"
    t.string "execution_mode", default: "llm", null: false
    t.string "native_function"
    t.boolean "active", default: true, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "native_params", default: {}, null: false
    t.index ["pipeline_stage_id", "position"], name: "index_stage_triggers_on_pipeline_stage_id_and_position"
    t.index ["pipeline_stage_id"], name: "index_stage_triggers_on_pipeline_stage_id"
    t.index ["workspace_id"], name: "index_stage_triggers_on_workspace_id"
  end

  create_table "stripe_connections", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "user_id", null: false
    t.text "api_key"
    t.string "account_label"
    t.boolean "sync_enabled", default: false, null: false
    t.datetime "last_synced_at"
    t.bigint "sync_cursor"
    t.string "last_error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_stripe_connections_on_user_id"
    t.index ["workspace_id"], name: "index_stripe_connections_on_workspace_id", unique: true
  end

  create_table "stripe_payments", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "stripe_connection_id", null: false
    t.string "stripe_charge_id", null: false
    t.integer "amount_cents", default: 0, null: false
    t.string "currency", default: "eur", null: false
    t.string "customer_email"
    t.string "customer_name"
    t.string "stripe_customer_id"
    t.string "description"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "paid_at", null: false
    t.boolean "refunded", default: false, null: false
    t.boolean "livemode", default: true, null: false
    t.string "status", default: "pending_review", null: false
    t.bigint "deal_id"
    t.bigint "suggested_deal_id"
    t.bigint "suggested_person_id"
    t.string "match_confidence"
    t.bigint "matched_by_id"
    t.datetime "matched_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "payload", default: {}, null: false
    t.index ["customer_email"], name: "index_stripe_payments_on_customer_email"
    t.index ["deal_id"], name: "index_stripe_payments_on_deal_id"
    t.index ["matched_by_id"], name: "index_stripe_payments_on_matched_by_id"
    t.index ["stripe_connection_id"], name: "index_stripe_payments_on_stripe_connection_id"
    t.index ["suggested_deal_id"], name: "index_stripe_payments_on_suggested_deal_id"
    t.index ["suggested_person_id"], name: "index_stripe_payments_on_suggested_person_id"
    t.index ["workspace_id", "status"], name: "index_stripe_payments_on_workspace_id_and_status"
    t.index ["workspace_id", "stripe_charge_id"], name: "index_stripe_payments_on_workspace_id_and_stripe_charge_id", unique: true
    t.index ["workspace_id"], name: "index_stripe_payments_on_workspace_id"
  end

  create_table "subscription_types", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.text "description"
    t.integer "position", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "consent_field_key"
    t.text "default_consent_label"
    t.boolean "excluded_from_subscribe_all", default: false, null: false
    t.index ["workspace_id", "consent_field_key"], name: "index_subscription_types_on_workspace_consent_field_key", unique: true, where: "(consent_field_key IS NOT NULL)"
    t.index ["workspace_id", "slug"], name: "index_subscription_types_on_workspace_id_and_slug", unique: true
    t.index ["workspace_id"], name: "index_subscription_types_on_workspace_id"
  end

  create_table "tasks", force: :cascade do |t|
    t.bigint "assignee_id"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.date "due_on"
    t.bigint "taskable_id"
    t.string "taskable_type"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "workspace_id", null: false
    t.index ["assignee_id"], name: "index_tasks_on_assignee_id"
    t.index ["taskable_type", "taskable_id"], name: "index_tasks_on_taskable"
    t.index ["user_id"], name: "index_tasks_on_user_id"
    t.index ["workspace_id", "assignee_id", "completed_at", "due_on"], name: "index_tasks_on_ws_assignee_completed_due"
    t.index ["workspace_id", "completed_at"], name: "index_tasks_on_workspace_id_and_completed_at"
    t.index ["workspace_id"], name: "index_tasks_on_workspace_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "name", default: "", null: false
    t.string "password_digest", null: false
    t.string "provider"
    t.string "uid"
    t.datetime "updated_at", null: false
    t.jsonb "sidebar_prefs", default: {}, null: false
    t.string "theme", default: "system", null: false
    t.string "locale", default: "es", null: false
    t.string "time_zone"
    t.boolean "superadmin", default: false, null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true, where: "((provider IS NOT NULL) AND (uid IS NOT NULL))"
  end

  create_table "versions", force: :cascade do |t|
    t.string "whodunnit"
    t.datetime "created_at"
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.string "event", null: false
    t.text "object"
    t.bigint "workspace_id"
    t.text "object_changes"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
    t.index ["workspace_id", "created_at"], name: "index_versions_on_workspace_id_and_created_at"
  end

  create_table "webhook_deliveries", force: :cascade do |t|
    t.bigint "webhook_id", null: false
    t.string "event", null: false
    t.jsonb "payload", default: {}, null: false
    t.integer "response_code"
    t.text "response_body"
    t.string "status", default: "pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["webhook_id"], name: "index_webhook_deliveries_on_webhook_id"
  end

  create_table "webhooks", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "user_id", null: false
    t.string "url", null: false
    t.string "secret"
    t.jsonb "events", default: [], null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_webhooks_on_user_id"
    t.index ["workspace_id"], name: "index_webhooks_on_workspace_id"
  end

  create_table "workspaces", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.boolean "sales_director_enabled", default: false, null: false
    t.boolean "okm_chat_enabled", default: false, null: false
    t.boolean "salespeople_can_view_all_deals", default: false, null: false
    t.boolean "salespeople_can_edit_all_deals", default: false, null: false
    t.string "okm_drive_id"
    t.text "okm_service_account_key"
    t.boolean "reports_enabled", default: false, null: false
    t.boolean "marketing_attribution_enabled", default: false, null: false
    t.boolean "lead_scoring_enabled", default: false, null: false
    t.boolean "webhooks_enabled", default: false, null: false
    t.boolean "custom_fields_enabled", default: false, null: false
    t.string "time_zone", default: "Europe/Madrid", null: false
    t.string "ga_measurement_id"
    t.bigint "public_layout_template_id"
    t.string "email_domain"
    t.index ["email_domain"], name: "index_workspaces_on_email_domain", unique: true, where: "(email_domain IS NOT NULL)"
    t.index ["public_layout_template_id"], name: "index_workspaces_on_public_layout_template_id"
    t.index ["slug"], name: "index_workspaces_on_slug", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "activities", "users"
  add_foreign_key "activities", "workspaces"
  add_foreign_key "alert_conditions", "alert_rules"
  add_foreign_key "alert_conditions", "workspaces"
  add_foreign_key "alert_deliveries", "alert_rules"
  add_foreign_key "alert_deliveries", "deals"
  add_foreign_key "alert_deliveries", "users"
  add_foreign_key "alert_rules", "workspaces"
  add_foreign_key "api_tokens", "users"
  add_foreign_key "api_tokens", "workspaces"
  add_foreign_key "automations", "workspaces"
  add_foreign_key "beehiiv_connections", "users"
  add_foreign_key "beehiiv_connections", "workspaces"
  add_foreign_key "beehiiv_publications", "beehiiv_connections"
  add_foreign_key "beehiiv_publications", "subscription_types"
  add_foreign_key "booking_event_types", "booking_pages"
  add_foreign_key "booking_event_types", "email_templates", on_delete: :nullify
  add_foreign_key "booking_event_types", "lead_form_templates", column: "success_template_id"
  add_foreign_key "booking_pages", "lead_form_templates", column: "success_template_id"
  add_foreign_key "booking_pages", "pipelines"
  add_foreign_key "booking_pages", "users", column: "host_id"
  add_foreign_key "booking_pages", "workspaces"
  add_foreign_key "bookings", "booking_event_types"
  add_foreign_key "bookings", "booking_pages"
  add_foreign_key "bookings", "campaigns"
  add_foreign_key "bookings", "deals"
  add_foreign_key "bookings", "people"
  add_foreign_key "bookings", "workspaces"
  add_foreign_key "calendar_connections", "users"
  add_foreign_key "calendar_connections", "workspaces"
  add_foreign_key "campaign_sends", "campaigns"
  add_foreign_key "campaign_sends", "email_templates"
  add_foreign_key "campaign_sends", "journeys"
  add_foreign_key "campaign_sends", "segments"
  add_foreign_key "campaign_sends", "subscription_types"
  add_foreign_key "campaign_sends", "users"
  add_foreign_key "campaign_sends", "workspaces"
  add_foreign_key "campaign_variants", "campaign_sends"
  add_foreign_key "campaigns", "email_layouts", on_delete: :nullify
  add_foreign_key "campaigns", "email_templates", on_delete: :nullify
  add_foreign_key "campaigns", "workspaces"
  add_foreign_key "comments", "comments", column: "parent_id"
  add_foreign_key "comments", "users"
  add_foreign_key "comments", "workspaces"
  add_foreign_key "companies", "users", column: "owner_id"
  add_foreign_key "companies", "workspaces"
  add_foreign_key "custom_field_values", "custom_fields"
  add_foreign_key "custom_field_values", "workspaces"
  add_foreign_key "custom_fields", "workspaces"
  add_foreign_key "deal_accesses", "deals"
  add_foreign_key "deal_accesses", "users"
  add_foreign_key "deal_contacts", "deals"
  add_foreign_key "deal_contacts", "people"
  add_foreign_key "deal_products", "deals"
  add_foreign_key "deal_products", "editions"
  add_foreign_key "deal_products", "products"
  add_foreign_key "deals", "campaigns"
  add_foreign_key "deals", "companies"
  add_foreign_key "deals", "companies", column: "partner_id"
  add_foreign_key "deals", "pipeline_stages"
  add_foreign_key "deals", "pipelines"
  add_foreign_key "deals", "users", column: "owner_id"
  add_foreign_key "deals", "workspaces"
  add_foreign_key "editions", "products"
  add_foreign_key "editions", "workspaces"
  add_foreign_key "email_events", "email_messages"
  add_foreign_key "email_layouts", "workspaces"
  add_foreign_key "email_messages", "campaign_variants"
  add_foreign_key "email_messages", "campaigns"
  add_foreign_key "email_messages", "email_messages", column: "in_reply_to_id"
  add_foreign_key "email_messages", "users"
  add_foreign_key "email_messages", "workspaces"
  add_foreign_key "email_subscriptions", "people"
  add_foreign_key "email_subscriptions", "subscription_types"
  add_foreign_key "email_subscriptions", "workspaces"
  add_foreign_key "email_suppressions", "workspaces"
  add_foreign_key "email_templates", "email_layouts", on_delete: :nullify
  add_foreign_key "email_templates", "users"
  add_foreign_key "email_templates", "workspaces"
  add_foreign_key "gmail_connections", "users"
  add_foreign_key "gmail_connections", "workspaces"
  add_foreign_key "invitations", "users", column: "invited_by_id"
  add_foreign_key "invitations", "workspaces"
  add_foreign_key "journey_enrollments", "journey_steps", column: "current_step_id"
  add_foreign_key "journey_enrollments", "journeys"
  add_foreign_key "journey_enrollments", "people"
  add_foreign_key "journey_enrollments", "workspaces"
  add_foreign_key "journey_steps", "journeys"
  add_foreign_key "journeys", "products"
  add_foreign_key "journeys", "workspaces"
  add_foreign_key "lead_form_templates", "workspaces"
  add_foreign_key "lead_forms", "email_templates"
  add_foreign_key "lead_forms", "pipeline_stages"
  add_foreign_key "lead_forms", "pipelines"
  add_foreign_key "lead_forms", "products"
  add_foreign_key "lead_forms", "subscription_types"
  add_foreign_key "lead_forms", "users", column: "responsible_id"
  add_foreign_key "lead_forms", "workspaces"
  add_foreign_key "lead_submissions", "campaigns"
  add_foreign_key "lead_submissions", "deals"
  add_foreign_key "lead_submissions", "lead_forms"
  add_foreign_key "lead_submissions", "people"
  add_foreign_key "lead_submissions", "privacy_policy_versions"
  add_foreign_key "lead_submissions", "workspaces"
  add_foreign_key "list_entries", "lists"
  add_foreign_key "list_filter_states", "sessions"
  add_foreign_key "list_filter_states", "workspaces"
  add_foreign_key "lists", "workspaces"
  add_foreign_key "llmemory_edges", "llmemory_nodes", column: "object_id"
  add_foreign_key "llmemory_edges", "llmemory_nodes", column: "subject_id"
  add_foreign_key "mailjet_connections", "users"
  add_foreign_key "mailjet_connections", "workspaces"
  add_foreign_key "marketing_product_interests", "deals"
  add_foreign_key "marketing_product_interests", "lead_submissions"
  add_foreign_key "marketing_product_interests", "people"
  add_foreign_key "marketing_product_interests", "products"
  add_foreign_key "marketing_product_interests", "users", column: "converted_by_id"
  add_foreign_key "marketing_product_interests", "users", column: "recorded_by_id"
  add_foreign_key "marketing_product_interests", "workspaces"
  add_foreign_key "memberships", "pipelines", column: "current_pipeline_id", on_delete: :nullify
  add_foreign_key "memberships", "users"
  add_foreign_key "memberships", "workspaces"
  add_foreign_key "notes", "users"
  add_foreign_key "notes", "workspaces"
  add_foreign_key "notifications", "users"
  add_foreign_key "notifications", "users", column: "actor_id"
  add_foreign_key "notifications", "workspaces"
  add_foreign_key "oauth_access_grants", "oauth_applications", column: "application_id"
  add_foreign_key "oauth_access_tokens", "oauth_applications", column: "application_id"
  add_foreign_key "offer_versions", "offers"
  add_foreign_key "offer_versions", "users"
  add_foreign_key "offers", "deals"
  add_foreign_key "offers", "users"
  add_foreign_key "offers", "workspaces"
  add_foreign_key "page_views", "people"
  add_foreign_key "page_views", "workspaces"
  add_foreign_key "people", "companies"
  add_foreign_key "people", "users", column: "brought_by_id"
  add_foreign_key "people", "users", column: "owner_id"
  add_foreign_key "people", "workspaces"
  add_foreign_key "person_emails", "people"
  add_foreign_key "person_emails", "workspaces"
  add_foreign_key "person_relationships", "people", column: "from_person_id"
  add_foreign_key "person_relationships", "people", column: "to_person_id"
  add_foreign_key "pipeline_stages", "pipelines"
  add_foreign_key "pipeline_stages", "workspaces"
  add_foreign_key "pipelines", "workspaces"
  add_foreign_key "privacy_policy_versions", "workspaces"
  add_foreign_key "products", "workspaces"
  add_foreign_key "record_attachments", "users"
  add_foreign_key "record_attachments", "workspaces"
  add_foreign_key "reports", "pipelines"
  add_foreign_key "reports", "users"
  add_foreign_key "reports", "workspaces"
  add_foreign_key "sales_briefings", "users"
  add_foreign_key "sales_briefings", "workspaces"
  add_foreign_key "saved_views", "users"
  add_foreign_key "saved_views", "workspaces"
  add_foreign_key "scoring_rules", "workspaces"
  add_foreign_key "segment_memberships", "people"
  add_foreign_key "segment_memberships", "segments"
  add_foreign_key "segment_memberships", "workspaces"
  add_foreign_key "segments", "users"
  add_foreign_key "segments", "workspaces"
  add_foreign_key "sessions", "users"
  add_foreign_key "slack_integrations", "workspaces"
  add_foreign_key "solid_queue_batch_executions", "solid_queue_batches", column: "batch_id", on_delete: :cascade
  add_foreign_key "solid_queue_batch_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "stage_conditions", "pipeline_stages"
  add_foreign_key "stage_conditions", "workspaces"
  add_foreign_key "stage_field_formats", "pipeline_stages"
  add_foreign_key "stage_field_formats", "workspaces"
  add_foreign_key "stage_trigger_runs", "deals"
  add_foreign_key "stage_trigger_runs", "stage_triggers"
  add_foreign_key "stage_trigger_runs", "users"
  add_foreign_key "stage_trigger_runs", "workspaces"
  add_foreign_key "stage_triggers", "pipeline_stages"
  add_foreign_key "stage_triggers", "workspaces"
  add_foreign_key "stripe_connections", "users"
  add_foreign_key "stripe_connections", "workspaces"
  add_foreign_key "stripe_payments", "deals"
  add_foreign_key "stripe_payments", "deals", column: "suggested_deal_id"
  add_foreign_key "stripe_payments", "people", column: "suggested_person_id"
  add_foreign_key "stripe_payments", "stripe_connections"
  add_foreign_key "stripe_payments", "users", column: "matched_by_id"
  add_foreign_key "stripe_payments", "workspaces"
  add_foreign_key "subscription_types", "workspaces"
  add_foreign_key "tasks", "users"
  add_foreign_key "tasks", "users", column: "assignee_id"
  add_foreign_key "tasks", "workspaces"
  add_foreign_key "webhook_deliveries", "webhooks"
  add_foreign_key "webhooks", "users"
  add_foreign_key "webhooks", "workspaces"
  add_foreign_key "workspaces", "lead_form_templates", column: "public_layout_template_id", on_delete: :nullify
end
