class CreatePrivacyPolicyVersions < ActiveRecord::Migration[8.0]
  def change
    create_table :privacy_policy_versions do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :content_hash, null: false
      t.string :policy_path, null: false
      t.text :policy_content, null: false
      t.text :statement_content, null: false
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :privacy_policy_versions, %i[workspace_id content_hash], unique: true

    add_reference :lead_submissions, :privacy_policy_version, foreign_key: true
  end
end
