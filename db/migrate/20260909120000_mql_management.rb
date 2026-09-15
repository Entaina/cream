class MqlManagement < ActiveRecord::Migration[8.0]
  def change
    add_column :lead_forms, :destination, :string, null: false, default: "deal"
    add_reference :lead_forms, :subscription_type, foreign_key: true
    add_column :lead_forms, :marketing_consent_text, :text
    change_column_null :lead_forms, :pipeline_id, true

    change_column_null :lead_submissions, :deal_id, true
    add_column :lead_submissions, :capture_destination, :string, null: false, default: "deal"
    add_column :lead_submissions, :submission_key, :string

    add_index :lead_submissions,
      %i[workspace_id lead_form_id submission_key],
      unique: true,
      where: "submission_key IS NOT NULL",
      name: "index_lead_submissions_on_form_submission_key"
    add_index :lead_submissions,
      %i[workspace_id lead_form_id person_id created_at],
      name: "index_lead_submissions_on_form_person_created"
    add_index :lead_submissions,
      %i[workspace_id person_id created_at],
      name: "index_lead_submissions_on_person_created"

    create_table :marketing_product_interests do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.references :recorded_by, foreign_key: {to_table: :users}
      t.references :deal, foreign_key: true
      t.references :converted_by, foreign_key: {to_table: :users}
      t.references :lead_submission, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.string :source_kind, null: false, default: "manual"
      t.text :description
      t.text :dismissal_reason
      t.datetime :occurred_at, null: false
      t.datetime :converted_at
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :marketing_product_interests,
      %i[workspace_id person_id status],
      name: "index_mql_interests_on_ws_person_status"
    add_index :marketing_product_interests,
      %i[workspace_id product_id status occurred_at],
      name: "index_mql_interests_on_ws_product_status_occurred"
    add_index :marketing_product_interests,
      %i[lead_submission_id product_id],
      unique: true,
      where: "lead_submission_id IS NOT NULL",
      name: "index_mql_interests_on_submission_product"

    add_reference :journeys, :product, foreign_key: true
    add_column :journeys, :stop_on_open_deal, :boolean, null: false, default: false
  end
end
