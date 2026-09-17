class AddSenderDomainValidatedToMailjetConnections < ActiveRecord::Migration[8.0]
  def change
    add_column :mailjet_connections, :sender_domain_validated, :boolean, null: false, default: false
  end
end
