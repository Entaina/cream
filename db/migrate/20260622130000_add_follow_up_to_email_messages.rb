class AddFollowUpToEmailMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :email_messages, :follow_up_at, :datetime
    add_column :email_messages, :replied_at, :datetime
    add_index :email_messages, :follow_up_at
  end
end
