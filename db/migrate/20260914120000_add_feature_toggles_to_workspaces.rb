class AddFeatureTogglesToWorkspaces < ActiveRecord::Migration[8.0]
  def change
    change_table :workspaces, bulk: true do |t|
      t.boolean :reports_enabled, default: false, null: false
      t.boolean :marketing_attribution_enabled, default: false, null: false
      t.boolean :lead_scoring_enabled, default: false, null: false
      t.boolean :webhooks_enabled, default: false, null: false
      t.boolean :custom_fields_enabled, default: false, null: false
    end
  end
end
