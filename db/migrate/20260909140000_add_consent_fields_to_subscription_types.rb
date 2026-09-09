class AddConsentFieldsToSubscriptionTypes < ActiveRecord::Migration[8.0]
  def change
    add_column :subscription_types, :consent_field_key, :string
    add_column :subscription_types, :default_consent_label, :text

    add_index :subscription_types,
              [ :workspace_id, :consent_field_key ],
              unique: true,
              where: "consent_field_key IS NOT NULL",
              name: "index_subscription_types_on_workspace_consent_field_key"

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          UPDATE subscription_types
          SET consent_field_key = 'marketing_consent'
          WHERE slug = 'general' AND consent_field_key IS NULL
        SQL
        execute <<~SQL.squish
          UPDATE subscription_types
          SET consent_field_key = 'newsletter_opt_in'
          WHERE slug = 'newsletter' AND consent_field_key IS NULL
        SQL
      end
    end
  end
end
