class CreateIntegrationsAndAutomations < ActiveRecord::Migration[8.1]
  def change
    create_table :webhooks do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :url, null: false
      t.string :secret
      t.jsonb :events, default: [], null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    create_table :webhook_deliveries do |t|
      t.references :webhook, null: false, foreign_key: true
      t.string :event, null: false
      t.jsonb :payload, default: {}, null: false
      t.integer :response_code
      t.text :response_body
      t.string :status, default: "pending", null: false

      t.timestamps
    end

    create_table :automations do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :name, null: false
      t.string :trigger_event, null: false
      t.jsonb :trigger_conditions, default: {}, null: false
      t.string :action_type, null: false
      t.jsonb :action_params, default: {}, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    create_table :slack_integrations do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :webhook_url, null: false
      t.boolean :active, default: true, null: false
      t.jsonb :notify_events, default: [], null: false

      t.timestamps
    end
  end
end
