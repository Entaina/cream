class AddExcludedFromSubscribeAllToSubscriptionTypes < ActiveRecord::Migration[8.0]
  def change
    add_column :subscription_types, :excluded_from_subscribe_all, :boolean, default: false, null: false
  end
end
