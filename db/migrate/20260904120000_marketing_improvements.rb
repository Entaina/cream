class MarketingImprovements < ActiveRecord::Migration[8.1]
  def change
    add_reference :campaign_sends, :subscription_type, foreign_key: true
    add_column :campaign_sends, :scheduled_at, :datetime

    add_reference :email_messages, :campaign_variant, foreign_key: true
    add_column :email_messages, :esp_message_id, :string
    add_index :email_messages, :esp_message_id

    add_column :people, :lead_score_decayed_at, :datetime

    add_index :journey_enrollments, [ :state, :next_run_at ], name: "idx_journey_enrollments_due"
    add_index :email_events, :occurred_at
  end
end
