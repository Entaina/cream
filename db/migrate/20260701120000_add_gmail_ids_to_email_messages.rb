class AddGmailIdsToEmailMessages < ActiveRecord::Migration[8.1]
  def change
    change_table :email_messages, bulk: true do |t|
      t.string :gmail_message_id
      t.string :gmail_thread_id
      t.string :rfc822_message_id
    end

    add_index :email_messages, :gmail_message_id
    add_index :email_messages, :gmail_thread_id
    add_index :email_messages, :rfc822_message_id
  end
end
