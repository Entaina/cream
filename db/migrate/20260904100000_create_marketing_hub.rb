class CreateMarketingHub < ActiveRecord::Migration[8.1]
  def change
    create_table :subscription_types do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :subscription_types, [ :workspace_id, :slug ], unique: true

    create_table :email_subscriptions do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true
      t.references :subscription_type, null: false, foreign_key: true
      t.string :status, null: false, default: "subscribed"
      t.datetime :opted_in_at
      t.datetime :opted_out_at
      t.string :source
      t.string :legal_basis
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :email_subscriptions, [ :person_id, :subscription_type_id ], unique: true, name: "idx_email_subscriptions_person_type"

    create_table :email_suppressions do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :address, null: false
      t.string :reason, null: false
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :email_suppressions, [ :workspace_id, :address ], unique: true

    create_table :email_events do |t|
      t.references :email_message, null: false, foreign_key: true
      t.string :event_type, null: false
      t.string :url
      t.datetime :occurred_at, null: false
      t.jsonb :payload, null: false, default: {}
      t.timestamps
    end
    add_index :email_events, [ :email_message_id, :event_type, :occurred_at ], name: "idx_email_events_message_type_at"

    create_table :campaigns do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :name, null: false
      t.string :status, null: false, default: "draft"
      t.date :starts_on
      t.text :goal
      t.string :utm_source
      t.string :utm_medium
      t.string :utm_campaign
      t.string :utm_term
      t.string :utm_content
      t.timestamps
    end

    create_table :segments do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :record_type, null: false, default: "Person"
      t.jsonb :filters, null: false, default: {}
      t.text :description
      t.boolean :shared, null: false, default: false
      t.timestamps
    end

    create_table :campaign_sends do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :campaign, null: false, foreign_key: true
      t.references :segment, null: false, foreign_key: true
      t.references :email_template, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.datetime :started_at
      t.datetime :completed_at
      t.jsonb :stats, null: false, default: {}
      t.timestamps
    end

    create_table :campaign_variants do |t|
      t.references :campaign_send, null: false, foreign_key: true
      t.string :name, null: false
      t.string :subject, null: false
      t.text :body, null: false
      t.integer :weight, null: false, default: 50
      t.boolean :winner, null: false, default: false
      t.timestamps
    end

    create_table :journeys do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :name, null: false
      t.boolean :active, null: false, default: true
      t.string :entry_trigger, null: false
      t.jsonb :entry_config, null: false, default: {}
      t.integer :max_reenrollments, null: false, default: 0
      t.timestamps
    end

    create_table :journey_steps do |t|
      t.references :journey, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.string :step_type, null: false
      t.jsonb :config, null: false, default: {}
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :journey_steps, [ :journey_id, :position ]

    create_table :journey_enrollments do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :journey, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true
      t.references :current_step, foreign_key: { to_table: :journey_steps }
      t.string :state, null: false, default: "active"
      t.datetime :next_run_at
      t.datetime :enrolled_at, null: false
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :journey_enrollments, [ :journey_id, :person_id, :state ], name: "idx_journey_enrollments_journey_person_state"

    create_table :scoring_rules do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :name, null: false
      t.string :event_type
      t.jsonb :conditions, null: false, default: []
      t.integer :points, null: false, default: 0
      t.integer :decay_days
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    create_table :page_views do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :person, foreign_key: true
      t.string :anonymous_id, null: false
      t.string :url, null: false
      t.string :referrer
      t.string :utm_source
      t.string :utm_medium
      t.string :utm_campaign
      t.string :utm_term
      t.string :utm_content
      t.string :session_id
      t.datetime :occurred_at, null: false
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :page_views, [ :workspace_id, :anonymous_id, :occurred_at ], name: "idx_page_views_workspace_anon_at"
    add_index :page_views, [ :workspace_id, :person_id, :occurred_at ], name: "idx_page_views_workspace_person_at"

    add_column :people, :lead_score, :integer, null: false, default: 0
    add_column :people, :lifecycle_stage, :string, null: false, default: "subscriber"
    add_index :people, [ :workspace_id, :lifecycle_stage ]

    add_reference :email_messages, :campaign, foreign_key: true
    add_reference :lead_submissions, :campaign, foreign_key: true
    add_reference :bookings, :campaign, foreign_key: true
    add_reference :deals, :campaign, foreign_key: true

    add_column :lead_form_templates, :page_slug, :string
    add_index :lead_form_templates, [ :workspace_id, :page_slug ], unique: true, where: "page_slug IS NOT NULL"
    add_column :email_messages, :marketing_send, :boolean, null: false, default: false
  end
end
