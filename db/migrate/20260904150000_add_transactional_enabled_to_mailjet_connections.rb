class AddTransactionalEnabledToMailjetConnections < ActiveRecord::Migration[8.1]
  def change
    add_column :mailjet_connections, :transactional_enabled, :boolean, null: false, default: false
  end
end
