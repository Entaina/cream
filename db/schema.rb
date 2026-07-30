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

ActiveRecord::Schema[8.1].define(version: 2026_07_30_100000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
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

  create_table "alert_deliveries", force: :cascade do |t|
    t.bigint "alert_rule_id", null: false
    t.datetime "created_at", null: false
    t.bigint "deal_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["alert_rule_id", "deal_id", "user_id"], name: "idx_on_alert_rule_id_deal_id_user_id_5c7d586558", unique: true
    t.index ["alert_rule_id"], name: "index_alert_deliveries_on_alert_rule_id"
    t.index ["deal_id"], name: "index_alert_deliveries_on_deal_id"
    t.index ["user_id"], name: "index_alert_deliveries_on_user_id"
  end

  create_table "alert_rules", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.jsonb "conditions", default: [], null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "offset_days", default: 0, null: false
    t.string "recipient", default: "deal_owner", null: false
    t.string "trigger_field", null: false
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
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
    t.jsonb "action_params", default: {}, null: false
    t.string "action_type", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.jsonb "trigger_conditions", default: {}, null: false
    t.string "trigger_event", null: false
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["workspace_id"], name: "index_automations_on_workspace_id"
  end

  create_table "booking_event_types", force: :cascade do |t|
    t.bigint "booking_page_id", null: false
    t.integer "buffer_after_minutes", default: 0, null: false
    t.integer "buffer_before_minutes", default: 0, null: false
    t.string "color", default: "hoki", null: false
    t.datetime "created_at", null: false
    t.jsonb "description_i18n", default: {}, null: false
    t.integer "duration_minutes", null: false
    t.string "location_address"
    t.string "location_type", default: "google_meet", null: false
    t.integer "min_notice_hours", default: 4, null: false
    t.jsonb "name_i18n", default: {}, null: false
    t.integer "position", default: 0, null: false
    t.integer "slot_increment_minutes", default: 15, null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.boolean "visible", default: true, null: false
    t.jsonb "weekly_hours", default: {}, null: false
    t.index ["booking_page_id", "slug"], name: "index_booking_event_types_on_booking_page_id_and_slug", unique: true
    t.index ["booking_page_id"], name: "index_booking_event_types_on_booking_page_id"
  end

  create_table "booking_pages", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "avatar_url"
    t.integer "booking_window_days", default: 60, null: false
    t.jsonb "calendar_ids", default: ["primary"], null: false
    t.datetime "created_at", null: false
    t.bigint "host_id", null: false
    t.string "logo_url"
    t.string "name", null: false
    t.bigint "pipeline_id", null: false
    t.string "slug", null: false
    t.string "timezone", default: "Europe/Madrid", null: false
    t.datetime "updated_at", null: false
    t.text "welcome_message"
    t.bigint "workspace_id", null: false
    t.index ["host_id"], name: "index_booking_pages_on_host_id"
    t.index ["pipeline_id"], name: "index_booking_pages_on_pipeline_id"
    t.index ["slug"], name: "index_booking_pages_on_slug", unique: true
    t.index ["workspace_id"], name: "index_booking_pages_on_workspace_id"
  end

  create_table "bookings", force: :cascade do |t|
    t.bigint "booking_event_type_id", null: false
    t.bigint "booking_page_id", null: false
    t.datetime "created_at", null: false
    t.bigint "deal_id"
    t.string "email", null: false
    t.datetime "ends_at", null: false
    t.string "first_name", null: false
    t.string "google_event_id"
    t.string "google_event_link"
    t.jsonb "guest_emails", default: [], null: false
    t.string "last_name", null: false
    t.string "meet_link"
    t.text "message"
    t.jsonb "metadata", default: {}, null: false
    t.bigint "person_id"
    t.string "phone"
    t.datetime "starts_at", null: false
    t.string "status", default: "confirmed", null: false
    t.string "timezone", null: false
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["booking_event_type_id"], name: "index_bookings_on_booking_event_type_id"
    t.index ["booking_page_id", "starts_at"], name: "index_bookings_on_booking_page_id_and_starts_at"
    t.index ["booking_page_id"], name: "index_bookings_on_booking_page_id"
    t.index ["deal_id"], name: "index_bookings_on_deal_id"
    t.index ["email"], name: "index_bookings_on_email"
    t.index ["person_id"], name: "index_bookings_on_person_id"
    t.index ["workspace_id"], name: "index_bookings_on_workspace_id"
  end

  create_table "calendar_connections", force: :cascade do |t|
    t.text "access_token"
    t.datetime "created_at", null: false
    t.string "email"
    t.datetime "expires_at"
    t.text "granted_scopes"
    t.text "refresh_token"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "workspace_id", null: false
    t.index ["user_id"], name: "index_calendar_connections_on_user_id"
    t.index ["workspace_id", "user_id"], name: "index_calendar_connections_on_workspace_id_and_user_id", unique: true
    t.index ["workspace_id"], name: "index_calendar_connections_on_workspace_id"
  end

  create_table "comments", force: :cascade do |t|
    t.text "body", null: false
    t.bigint "commentable_id", null: false
    t.string "commentable_type", null: false
    t.datetime "created_at", null: false
    t.bigint "parent_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "workspace_id", null: false
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
    t.text "fiscal_information"
    t.string "industry"
    t.string "linkedin_url"
    t.string "location"
    t.string "name", null: false
    t.bigint "owner_id"
    t.string "twitter_url"
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["owner_id"], name: "index_companies_on_owner_id"
    t.index ["workspace_id", "domain"], name: "index_companies_on_workspace_id_and_domain"
    t.index ["workspace_id", "name"], name: "index_companies_on_workspace_id_and_name"
    t.index ["workspace_id"], name: "index_companies_on_workspace_id"
  end

  create_table "custom_field_values", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "custom_field_id", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.jsonb "value"
    t.bigint "workspace_id", null: false
    t.index ["custom_field_id", "record_type", "record_id"], name: "index_custom_field_values_on_field_and_record", unique: true
    t.index ["custom_field_id"], name: "index_custom_field_values_on_custom_field_id"
    t.index ["record_type", "record_id"], name: "index_custom_field_values_on_record"
    t.index ["record_type", "record_id"], name: "index_custom_field_values_on_record_type_and_record_id"
    t.index ["workspace_id"], name: "index_custom_field_values_on_workspace_id"
  end

  create_table "custom_fields", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "field_type", null: false
    t.text "formula_expression"
    t.string "key", null: false
    t.string "name", null: false
    t.jsonb "options", default: [], null: false
    t.integer "position", default: 0, null: false
    t.string "record_type", null: false
    t.string "reference_type"
    t.boolean "required", default: false, null: false
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["workspace_id", "record_type", "key"], name: "index_custom_fields_on_workspace_id_and_record_type_and_key", unique: true
    t.index ["workspace_id", "record_type", "position"], name: "idx_on_workspace_id_record_type_position_e95e0d1f7e"
    t.index ["workspace_id"], name: "index_custom_fields_on_workspace_id"
  end

  create_table "deal_accesses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "deal_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["deal_id", "user_id"], name: "index_deal_accesses_on_deal_id_and_user_id", unique: true
    t.index ["deal_id"], name: "index_deal_accesses_on_deal_id"
    t.index ["user_id"], name: "index_deal_accesses_on_user_id"
  end

  create_table "deal_contacts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "deal_id", null: false
    t.bigint "person_id", null: false
    t.datetime "updated_at", null: false
    t.index ["deal_id", "person_id"], name: "index_deal_contacts_on_deal_id_and_person_id", unique: true
    t.index ["deal_id"], name: "index_deal_contacts_on_deal_id"
    t.index ["person_id"], name: "index_deal_contacts_on_person_id"
  end

  create_table "deal_products", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "deal_id", null: false
    t.bigint "edition_id"
    t.bigint "product_id", null: false
    t.integer "quantity", default: 1, null: false
    t.decimal "unit_price", precision: 14, scale: 2, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.index ["deal_id"], name: "index_deal_products_on_deal_id"
    t.index ["edition_id"], name: "index_deal_products_on_edition_id"
    t.index ["product_id"], name: "index_deal_products_on_product_id"
  end

  create_table "deals", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "EUR", null: false
    t.date "expected_close_date"
    t.string "invoice_number"
    t.string "name", null: false
    t.bigint "owner_id"
    t.bigint "partner_id"
    t.bigint "pipeline_id", null: false
    t.bigint "pipeline_stage_id", null: false
    t.integer "position", default: 0, null: false
    t.integer "probability", default: 0
    t.datetime "updated_at", null: false
    t.decimal "value", precision: 14, scale: 2, default: "0.0"
    t.bigint "workspace_id", null: false
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
    t.datetime "created_at", null: false
    t.date "ends_on"
    t.string "name", null: false
    t.date "starts_on"
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["workspace_id", "name"], name: "index_editions_on_workspace_id_and_name", unique: true
    t.index ["workspace_id"], name: "index_editions_on_workspace_id"
  end

  create_table "email_messages", force: :cascade do |t|
    t.text "body", null: false
    t.integer "clicks_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "direction", default: "outbound", null: false
    t.datetime "follow_up_at"
    t.string "from_address"
    t.string "gmail_message_id"
    t.string "gmail_thread_id"
    t.bigint "in_reply_to_id"
    t.string "mail_merge_batch_id"
    t.datetime "opened_at"
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.datetime "replied_at"
    t.string "rfc822_message_id"
    t.datetime "scheduled_at"
    t.string "status", default: "sent", null: false
    t.string "subject", null: false
    t.string "to_address", null: false
    t.string "tracking_token"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "workspace_id", null: false
    t.index ["direction"], name: "index_email_messages_on_direction"
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

  create_table "email_templates", force: :cascade do |t|
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.string "key"
    t.string "name", null: false
    t.boolean "shared", default: false, null: false
    t.string "subject"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "workspace_id", null: false
    t.index ["user_id"], name: "index_email_templates_on_user_id"
    t.index ["workspace_id", "key"], name: "index_email_templates_on_workspace_id_and_key", unique: true, where: "(key IS NOT NULL)"
    t.index ["workspace_id"], name: "index_email_templates_on_workspace_id"
  end

  create_table "gmail_connections", force: :cascade do |t|
    t.text "access_token"
    t.datetime "created_at", null: false
    t.string "email"
    t.datetime "expires_at"
    t.text "granted_scopes"
    t.datetime "last_synced_at"
    t.text "refresh_token"
    t.boolean "send_enabled", default: false, null: false
    t.boolean "sync_enabled", default: false, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "workspace_id", null: false
    t.index ["user_id"], name: "index_gmail_connections_on_user_id"
    t.index ["workspace_id", "user_id"], name: "index_gmail_connections_on_workspace_id_and_user_id", unique: true
    t.index ["workspace_id"], name: "index_gmail_connections_on_workspace_id"
  end

  create_table "invitations", force: :cascade do |t|
    t.datetime "accepted_at"
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.datetime "expires_at", null: false
    t.bigint "invited_by_id", null: false
    t.string "role", default: "salesperson", null: false
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["invited_by_id"], name: "index_invitations_on_invited_by_id"
    t.index ["token_digest"], name: "index_invitations_on_token_digest", unique: true
    t.index ["workspace_id", "email_address"], name: "index_invitations_pending_on_workspace_and_email", unique: true, where: "(accepted_at IS NULL)"
    t.index ["workspace_id"], name: "index_invitations_on_workspace_id"
  end

  create_table "lead_forms", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.boolean "collects_company", default: false, null: false
    t.datetime "created_at", null: false
    t.bigint "email_template_id", null: false
    t.string "name", null: false
    t.bigint "pipeline_id", null: false
    t.jsonb "pipeline_routes", default: {}, null: false
    t.bigint "responsible_id", null: false
    t.string "slug", null: false
    t.string "template_key", null: false
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["email_template_id"], name: "index_lead_forms_on_email_template_id"
    t.index ["pipeline_id"], name: "index_lead_forms_on_pipeline_id"
    t.index ["responsible_id"], name: "index_lead_forms_on_responsible_id"
    t.index ["slug"], name: "index_lead_forms_on_slug", unique: true
    t.index ["workspace_id"], name: "index_lead_forms_on_workspace_id"
  end

  create_table "lead_submissions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "data", default: {}, null: false
    t.bigint "deal_id", null: false
    t.bigint "lead_form_id", null: false
    t.jsonb "metadata", default: {}, null: false
    t.bigint "person_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["deal_id"], name: "index_lead_submissions_on_deal_id", unique: true
    t.index ["lead_form_id"], name: "index_lead_submissions_on_lead_form_id"
    t.index ["person_id"], name: "index_lead_submissions_on_person_id"
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
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.jsonb "params", default: {}, null: false
    t.bigint "session_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
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
    t.string "category_name", null: false
    t.text "content", null: false
    t.datetime "updated_at", null: false
    t.string "user_id", null: false
    t.index ["user_id", "category_name"], name: "index_llmemory_categories_on_user_id_and_category_name", unique: true
  end

  create_table "llmemory_checkpoints", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "session_id", null: false
    t.jsonb "state", default: {}, null: false
    t.datetime "updated_at", null: false
    t.string "user_id", null: false
    t.index ["user_id", "session_id"], name: "index_llmemory_checkpoints_on_user_id_and_session_id", unique: true
  end

  create_table "llmemory_edges", force: :cascade do |t|
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.bigint "object_id", null: false
    t.string "predicate", null: false
    t.jsonb "properties", default: {}
    t.bigint "subject_id", null: false
    t.datetime "updated_at", null: false
    t.string "user_id", null: false
    t.index ["object_id"], name: "index_llmemory_edges_on_object_id"
    t.index ["subject_id"], name: "index_llmemory_edges_on_subject_id"
    t.index ["user_id", "subject_id", "predicate"], name: "index_llmemory_edges_on_user_id_and_subject_id_and_predicate"
  end

# Could not dump table "llmemory_embeddings" because of following StandardError
#   Unknown type 'vector(1536)' for column 'embedding'


  create_table "llmemory_episodes", id: :string, force: :cascade do |t|
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.jsonb "data", default: {}, null: false
    t.text "search_text"
    t.text "search_tokens"
    t.datetime "updated_at", null: false
    t.string "user_id", null: false
    t.index ["user_id"], name: "index_llmemory_episodes_on_user_id"
  end

  create_table "llmemory_items", id: :string, force: :cascade do |t|
    t.string "category", null: false
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.float "importance", default: 0.7
    t.jsonb "provenance"
    t.text "search_tokens"
    t.string "source_resource_id"
    t.datetime "updated_at", null: false
    t.string "user_id", null: false
    t.index ["user_id"], name: "index_llmemory_items_on_user_id"
  end

  create_table "llmemory_nodes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "entity_type", null: false
    t.string "name", null: false
    t.jsonb "properties", default: {}
    t.datetime "updated_at", null: false
    t.string "user_id", null: false
    t.index ["user_id", "entity_type", "name"], name: "index_llmemory_nodes_on_user_id_and_entity_type_and_name", unique: true
  end

  create_table "llmemory_resources", id: :string, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "search_tokens"
    t.text "text", null: false
    t.datetime "updated_at", null: false
    t.string "user_id", null: false
    t.index ["user_id"], name: "index_llmemory_resources_on_user_id"
  end

  create_table "llmemory_skills", id: :string, force: :cascade do |t|
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.jsonb "data", default: {}, null: false
    t.text "name_det"
    t.text "search_text"
    t.text "search_tokens"
    t.datetime "updated_at", null: false
    t.string "user_id", null: false
    t.index ["user_id"], name: "index_llmemory_skills_on_user_id"
  end

  create_table "memberships", force: :cascade do |t|
    t.boolean "alert_email", default: false, null: false
    t.boolean "alert_in_app", default: true, null: false
    t.datetime "created_at", null: false
    t.bigint "current_pipeline_id"
    t.string "role", default: "salesperson", null: false
    t.integer "sales_briefing_regenerations_count", default: 0, null: false
    t.date "sales_briefing_regenerations_on"
    t.boolean "sales_director_briefing_enabled", default: true, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "workspace_id", null: false
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
    t.bigint "actor_id"
    t.text "body"
    t.datetime "created_at", null: false
    t.string "kind", null: false
    t.datetime "read_at"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.string "url"
    t.bigint "user_id", null: false
    t.bigint "workspace_id", null: false
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

  create_table "people", force: :cascade do |t|
    t.bigint "brought_by_id"
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "email"
    t.date "first_contact_on"
    t.string "first_name", default: "", null: false
    t.string "job_title"
    t.string "last_name", default: "", null: false
    t.string "linkedin_url"
    t.string "location"
    t.bigint "owner_id"
    t.string "phone"
    t.string "source"
    t.string "twitter_url"
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["brought_by_id"], name: "index_people_on_brought_by_id"
    t.index ["company_id"], name: "index_people_on_company_id"
    t.index ["owner_id"], name: "index_people_on_owner_id"
    t.index ["workspace_id", "email"], name: "index_people_on_workspace_id_and_email"
    t.index ["workspace_id", "last_name", "first_name"], name: "index_people_on_workspace_id_and_last_name_and_first_name"
    t.index ["workspace_id"], name: "index_people_on_workspace_id"
  end

  create_table "person_emails", force: :cascade do |t|
    t.string "address", null: false
    t.datetime "created_at", null: false
    t.bigint "person_id", null: false
    t.boolean "primary", default: false, null: false
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["person_id", "primary"], name: "index_person_emails_on_person_id_and_primary"
    t.index ["person_id"], name: "index_person_emails_on_person_id"
    t.index ["workspace_id", "address"], name: "index_person_emails_on_workspace_id_and_address"
    t.index ["workspace_id"], name: "index_person_emails_on_workspace_id"
  end

  create_table "person_relationships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "from_person_id", null: false
    t.string "relationship_type", null: false
    t.bigint "to_person_id", null: false
    t.datetime "updated_at", null: false
    t.index ["from_person_id", "to_person_id", "relationship_type"], name: "index_person_relationships_on_from_to_type", unique: true
    t.index ["from_person_id"], name: "index_person_relationships_on_from_person_id"
    t.index ["to_person_id"], name: "index_person_relationships_on_to_person_id"
  end

  create_table "pipeline_stages", force: :cascade do |t|
    t.boolean "closed", default: false, null: false
    t.string "color", default: "chicago", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "pipeline_id", null: false
    t.integer "position", default: 0, null: false
    t.integer "probability", default: 0, null: false
    t.datetime "updated_at", null: false
    t.boolean "won", default: false, null: false
    t.bigint "workspace_id", null: false
    t.index ["pipeline_id", "position"], name: "index_pipeline_stages_on_pipeline_id_and_position"
    t.index ["pipeline_id"], name: "index_pipeline_stages_on_pipeline_id"
    t.index ["workspace_id"], name: "index_pipeline_stages_on_workspace_id"
  end

  create_table "pipelines", force: :cascade do |t|
    t.string "card_fields", default: ["value", "company", "expected_close_date", "owner"], null: false, array: true
    t.datetime "created_at", null: false
    t.boolean "default_pipeline", default: false, null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["workspace_id"], name: "index_pipelines_on_workspace_id"
  end

  create_table "products", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.decimal "price", precision: 14, scale: 2, default: "0.0", null: false
    t.string "segment"
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["workspace_id", "name"], name: "index_products_on_workspace_id_and_name"
    t.index ["workspace_id"], name: "index_products_on_workspace_id"
  end

  create_table "record_attachments", force: :cascade do |t|
    t.bigint "attachable_id", null: false
    t.string "attachable_type", null: false
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "workspace_id", null: false
    t.index ["attachable_type", "attachable_id"], name: "index_record_attachments_on_attachable"
    t.index ["user_id"], name: "index_record_attachments_on_user_id"
    t.index ["workspace_id"], name: "index_record_attachments_on_workspace_id"
  end

  create_table "reports", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "date_range", default: "all", null: false
    t.string "group_by", null: false
    t.datetime "last_sent_at"
    t.string "metric", null: false
    t.string "name", null: false
    t.bigint "pipeline_id"
    t.string "record_type", null: false
    t.string "schedule", default: "none", null: false
    t.boolean "shared", default: false, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "workspace_id", null: false
    t.index ["pipeline_id"], name: "index_reports_on_pipeline_id"
    t.index ["user_id"], name: "index_reports_on_user_id"
    t.index ["workspace_id"], name: "index_reports_on_workspace_id"
  end

  create_table "sales_briefings", force: :cascade do |t|
    t.date "briefing_date", null: false
    t.datetime "created_at", null: false
    t.datetime "generated_at", null: false
    t.jsonb "items", default: [], null: false
    t.jsonb "misses", default: [], null: false
    t.text "summary"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.jsonb "wins", default: [], null: false
    t.bigint "workspace_id", null: false
    t.index ["user_id"], name: "index_sales_briefings_on_user_id"
    t.index ["workspace_id", "briefing_date"], name: "index_sales_briefings_team_unique", unique: true, where: "(user_id IS NULL)"
    t.index ["workspace_id", "user_id", "briefing_date"], name: "index_sales_briefings_personal_unique", unique: true, where: "(user_id IS NOT NULL)"
    t.index ["workspace_id"], name: "index_sales_briefings_on_workspace_id"
  end

  create_table "saved_views", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "direction", default: "asc", null: false
    t.jsonb "filters", default: {}, null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.string "record_type", null: false
    t.boolean "shared", default: false, null: false
    t.string "sort"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "workspace_id", null: false
    t.index ["user_id"], name: "index_saved_views_on_user_id"
    t.index ["workspace_id", "record_type"], name: "index_saved_views_on_workspace_id_and_record_type"
    t.index ["workspace_id"], name: "index_saved_views_on_workspace_id"
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
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.jsonb "notify_events", default: [], null: false
    t.datetime "updated_at", null: false
    t.string "webhook_url", null: false
    t.bigint "workspace_id", null: false
    t.index ["workspace_id"], name: "index_slack_integrations_on_workspace_id"
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", null: false
    t.bigint "channel_hash", null: false
    t.datetime "created_at", null: false
    t.binary "payload", null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "stage_conditions", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "compare_value"
    t.datetime "created_at", null: false
    t.string "field", null: false
    t.string "operator", default: "eq", null: false
    t.bigint "pipeline_stage_id", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["pipeline_stage_id"], name: "index_stage_conditions_on_pipeline_stage_id"
    t.index ["workspace_id"], name: "index_stage_conditions_on_workspace_id"
  end

  create_table "stage_field_formats", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "compare_value"
    t.datetime "created_at", null: false
    t.string "display_text", null: false
    t.string "field", null: false
    t.string "operator", default: "eq", null: false
    t.bigint "pipeline_stage_id", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["pipeline_stage_id", "field"], name: "index_stage_field_formats_on_pipeline_stage_id_and_field"
    t.index ["pipeline_stage_id"], name: "index_stage_field_formats_on_pipeline_stage_id"
    t.index ["workspace_id"], name: "index_stage_field_formats_on_workspace_id"
  end

  create_table "stage_trigger_runs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "deal_id", null: false
    t.text "error"
    t.datetime "finished_at"
    t.text "panel_markdown"
    t.string "panel_title"
    t.bigint "stage_trigger_id", null: false
    t.datetime "started_at"
    t.string "status", default: "pending", null: false
    t.jsonb "transcript", default: [], null: false
    t.jsonb "ui_actions", default: [], null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.bigint "workspace_id", null: false
    t.index ["deal_id", "created_at"], name: "index_stage_trigger_runs_on_deal_id_and_created_at"
    t.index ["deal_id"], name: "index_stage_trigger_runs_on_deal_id"
    t.index ["stage_trigger_id"], name: "index_stage_trigger_runs_on_stage_trigger_id"
    t.index ["user_id"], name: "index_stage_trigger_runs_on_user_id"
    t.index ["workspace_id"], name: "index_stage_trigger_runs_on_workspace_id"
  end

  create_table "stage_triggers", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "execution_mode", default: "llm", null: false
    t.text "instructions"
    t.string "name", null: false
    t.string "native_function"
    t.jsonb "native_params", default: {}, null: false
    t.bigint "pipeline_stage_id", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["pipeline_stage_id", "position"], name: "index_stage_triggers_on_pipeline_stage_id_and_position"
    t.index ["pipeline_stage_id"], name: "index_stage_triggers_on_pipeline_stage_id"
    t.index ["workspace_id"], name: "index_stage_triggers_on_workspace_id"
  end

  create_table "stripe_connections", force: :cascade do |t|
    t.string "account_label"
    t.text "api_key"
    t.datetime "created_at", null: false
    t.string "last_error"
    t.datetime "last_synced_at"
    t.bigint "sync_cursor"
    t.boolean "sync_enabled", default: false, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "workspace_id", null: false
    t.index ["user_id"], name: "index_stripe_connections_on_user_id"
    t.index ["workspace_id"], name: "index_stripe_connections_on_workspace_id", unique: true
  end

  create_table "stripe_payments", force: :cascade do |t|
    t.integer "amount_cents", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "eur", null: false
    t.string "customer_email"
    t.string "customer_name"
    t.bigint "deal_id"
    t.string "description"
    t.boolean "livemode", default: true, null: false
    t.string "match_confidence"
    t.datetime "matched_at"
    t.bigint "matched_by_id"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "paid_at", null: false
    t.jsonb "payload", default: {}, null: false
    t.boolean "refunded", default: false, null: false
    t.string "status", default: "pending_review", null: false
    t.string "stripe_charge_id", null: false
    t.bigint "stripe_connection_id", null: false
    t.string "stripe_customer_id"
    t.bigint "suggested_deal_id"
    t.bigint "suggested_person_id"
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
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
    t.jsonb "sidebar_prefs", default: {}, null: false
    t.string "theme", default: "system", null: false
    t.string "uid"
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true, where: "((provider IS NOT NULL) AND (uid IS NOT NULL))"
  end

  create_table "versions", force: :cascade do |t|
    t.datetime "created_at"
    t.string "event", null: false
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.text "object"
    t.text "object_changes"
    t.string "whodunnit"
    t.bigint "workspace_id"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
    t.index ["workspace_id", "created_at"], name: "index_versions_on_workspace_id_and_created_at"
  end

  create_table "webhook_deliveries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event", null: false
    t.jsonb "payload", default: {}, null: false
    t.text "response_body"
    t.integer "response_code"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.bigint "webhook_id", null: false
    t.index ["webhook_id"], name: "index_webhook_deliveries_on_webhook_id"
  end

  create_table "webhooks", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.jsonb "events", default: [], null: false
    t.string "secret"
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.bigint "user_id", null: false
    t.bigint "workspace_id", null: false
    t.index ["user_id"], name: "index_webhooks_on_user_id"
    t.index ["workspace_id"], name: "index_webhooks_on_workspace_id"
  end

  create_table "workspaces", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.boolean "okm_chat_enabled", default: false, null: false
    t.boolean "sales_director_enabled", default: false, null: false
    t.boolean "salespeople_can_edit_all_deals", default: false, null: false
    t.boolean "salespeople_can_view_all_deals", default: false, null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_workspaces_on_slug", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "activities", "users"
  add_foreign_key "activities", "workspaces"
  add_foreign_key "alert_deliveries", "alert_rules"
  add_foreign_key "alert_deliveries", "deals"
  add_foreign_key "alert_deliveries", "users"
  add_foreign_key "alert_rules", "workspaces"
  add_foreign_key "api_tokens", "users"
  add_foreign_key "api_tokens", "workspaces"
  add_foreign_key "automations", "workspaces"
  add_foreign_key "booking_event_types", "booking_pages"
  add_foreign_key "booking_pages", "pipelines"
  add_foreign_key "booking_pages", "users", column: "host_id"
  add_foreign_key "booking_pages", "workspaces"
  add_foreign_key "bookings", "booking_event_types"
  add_foreign_key "bookings", "booking_pages"
  add_foreign_key "bookings", "deals"
  add_foreign_key "bookings", "people"
  add_foreign_key "bookings", "workspaces"
  add_foreign_key "calendar_connections", "users"
  add_foreign_key "calendar_connections", "workspaces"
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
  add_foreign_key "deals", "companies"
  add_foreign_key "deals", "companies", column: "partner_id"
  add_foreign_key "deals", "pipeline_stages"
  add_foreign_key "deals", "pipelines"
  add_foreign_key "deals", "users", column: "owner_id"
  add_foreign_key "deals", "workspaces"
  add_foreign_key "editions", "workspaces"
  add_foreign_key "email_messages", "email_messages", column: "in_reply_to_id"
  add_foreign_key "email_messages", "users"
  add_foreign_key "email_messages", "workspaces"
  add_foreign_key "email_templates", "users"
  add_foreign_key "email_templates", "workspaces"
  add_foreign_key "gmail_connections", "users"
  add_foreign_key "gmail_connections", "workspaces"
  add_foreign_key "invitations", "users", column: "invited_by_id"
  add_foreign_key "invitations", "workspaces"
  add_foreign_key "lead_forms", "email_templates"
  add_foreign_key "lead_forms", "pipelines"
  add_foreign_key "lead_forms", "users", column: "responsible_id"
  add_foreign_key "lead_forms", "workspaces"
  add_foreign_key "lead_submissions", "deals"
  add_foreign_key "lead_submissions", "lead_forms"
  add_foreign_key "lead_submissions", "people"
  add_foreign_key "lead_submissions", "workspaces"
  add_foreign_key "list_entries", "lists"
  add_foreign_key "list_filter_states", "sessions"
  add_foreign_key "list_filter_states", "workspaces"
  add_foreign_key "lists", "workspaces"
  add_foreign_key "llmemory_edges", "llmemory_nodes", column: "object_id"
  add_foreign_key "llmemory_edges", "llmemory_nodes", column: "subject_id"
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
  add_foreign_key "sessions", "users"
  add_foreign_key "slack_integrations", "workspaces"
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
  add_foreign_key "tasks", "users"
  add_foreign_key "tasks", "users", column: "assignee_id"
  add_foreign_key "tasks", "workspaces"
  add_foreign_key "webhook_deliveries", "webhooks"
  add_foreign_key "webhooks", "users"
  add_foreign_key "webhooks", "workspaces"
end
