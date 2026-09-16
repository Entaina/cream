class AddJourneyDeliveryToCampaignSends < ActiveRecord::Migration[8.1]
  def change
    add_reference :campaign_sends, :journey, foreign_key: true
    add_column :campaign_sends, :delivery_mode, :string, null: false, default: "email"
  end
end
