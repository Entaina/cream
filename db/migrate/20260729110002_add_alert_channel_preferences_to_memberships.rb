class AddAlertChannelPreferencesToMemberships < ActiveRecord::Migration[8.0]
  def change
    add_column :memberships, :alert_in_app, :boolean, null: false, default: true
    add_column :memberships, :alert_email, :boolean, null: false, default: false
  end
end
