class AddEnglishConsentTextsToSubscriptionTypes < ActiveRecord::Migration[8.1]
  def change
    add_column :subscription_types, :default_consent_label_en, :text
    add_column :subscription_types, :description_en, :text
  end
end
