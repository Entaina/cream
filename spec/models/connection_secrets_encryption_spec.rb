require "rails_helper"

RSpec.describe "Connection secrets encryption" do
  fixtures :users, :workspaces, :memberships

  let(:user) { users(:one) }
  let(:workspace) { workspaces(:one) }

  builders = {
    GmailConnection => ->(ws, u) { GmailConnection.create!(workspace: ws, user: u, access_token: "gmail-access", refresh_token: "gmail-refresh") },
    CalendarConnection => ->(ws, u) { CalendarConnection.create!(workspace: ws, user: u, access_token: "cal-access", refresh_token: "cal-refresh") },
    MailjetConnection => ->(ws, u) { MailjetConnection.create!(workspace: ws, user: u, api_key: "mj-key", secret_key: "mj-secret", from_email: "news@example.com") },
    StripeConnection => ->(ws, u) { StripeConnection.create!(workspace: ws, user: u, api_key: "sk_test_secret") },
    BeehiivConnection => ->(ws, u) { BeehiivConnection.create!(workspace: ws, user: u, api_key: "beehiiv-key") },
    SmtpConnection => ->(ws, u) { SmtpConnection.create!(workspace: ws, user: u, address: "smtp.example.com", from_email: "crm@example.com", user_name: "crm", password: "smtp-pass") },
    Webhook => ->(ws, u) { Webhook.create!(workspace: ws, user: u, url: "https://example.com/hook", events: [Webhook::EVENTS.first], secret: "hook-secret") },
    Workspace => ->(ws, _u) { ws.tap { |w| w.update!(okm_service_account_key: {client_email: "okm@example.com", private_key: "okm-private"}.to_json) } }
  }

  expected_columns = {
    GmailConnection => %i[access_token refresh_token],
    CalendarConnection => %i[access_token refresh_token],
    MailjetConnection => %i[api_key secret_key],
    StripeConnection => %i[api_key],
    BeehiivConnection => %i[api_key],
    SmtpConnection => %i[password],
    Webhook => %i[secret],
    Workspace => %i[okm_service_account_key]
  }

  def raw_value(record, column)
    record.class.connection.select_value(
      "SELECT #{column} FROM #{record.class.table_name} WHERE id = #{record.id.to_i}"
    )
  end

  expected_columns.each do |model, columns|
    describe model.name do
      it "declares #{columns.join(", ")} as encrypted" do
        expect(model.encrypted_attributes).to include(*columns)
      end

      it "stores the secrets as ciphertext and reads them back" do
        record = builders.fetch(model).call(workspace, user)
        values = columns.index_with { |column| record.public_send(column) }

        columns.each do |column|
          expect(raw_value(record, column)).not_to include(values[column])
          expect(record.class.find(record.id).public_send(column)).to eq(values[column])
        end
      end

      it "still reads secrets stored in plaintext before encryption was enabled" do
        record = builders.fetch(model).call(workspace, user)
        plaintext = columns.index_with { |column| "legacy-#{column}" }
        ActiveRecord::Encryption.without_encryption { record.update_columns(plaintext) }

        columns.each do |column|
          expect(raw_value(record, column)).to eq(plaintext[column])
          expect(record.class.find(record.id).public_send(column)).to eq(plaintext[column])
        end
      end
    end
  end
end
