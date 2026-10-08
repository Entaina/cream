class AddClientPortalConsentToSubscriptionTypes < ActiveRecord::Migration[8.1]
  def change
    add_column :subscription_types, :client_portal_consent, :string, default: "none", null: false
  end
end
