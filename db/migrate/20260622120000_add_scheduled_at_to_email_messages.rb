class AddScheduledAtToEmailMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :email_messages, :scheduled_at, :datetime
    add_index :email_messages, :scheduled_at
  end
end
