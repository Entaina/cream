class AddApiTokenExpiryAndScope < ActiveRecord::Migration[8.1]
  def change
    add_column :api_tokens, :expires_at, :datetime
    add_column :api_tokens, :token_scope, :string, null: false, default: "write"
  end
end
