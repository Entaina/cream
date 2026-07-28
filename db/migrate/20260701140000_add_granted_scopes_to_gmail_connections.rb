class AddGrantedScopesToGmailConnections < ActiveRecord::Migration[8.1]
  def change
    add_column :gmail_connections, :granted_scopes, :text
  end
end
