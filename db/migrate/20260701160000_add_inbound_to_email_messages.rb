class AddInboundToEmailMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :email_messages, :direction, :string, null: false, default: "outbound"
    add_column :email_messages, :from_address, :string
    add_reference :email_messages, :in_reply_to, foreign_key: { to_table: :email_messages }
    add_index :email_messages, :direction
  end
end
