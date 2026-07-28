class AddSendFieldsToGmailConnections < ActiveRecord::Migration[8.1]
  def change
    add_column :gmail_connections, :email, :string
    add_column :gmail_connections, :send_enabled, :boolean, null: false, default: false
  end
end
