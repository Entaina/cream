require "rails_helper"
require "rake"

RSpec.describe "security:encrypt_connection_secrets" do
  fixtures :users, :workspaces, :memberships

  let(:user) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let(:task) { Rake::Task["security:encrypt_connection_secrets"] }

  before(:all) do
    Rake::Task.define_task(:environment) unless Rake::Task.task_defined?(:environment)
    load Rails.root.join("lib/tasks/encrypt_connection_secrets.rake").to_s unless Rake::Task.task_defined?("security:encrypt_connection_secrets")
  end

  after { task.reenable }

  def raw_value(model, id, column)
    model.connection.select_value("SELECT #{column} FROM #{model.table_name} WHERE id = #{id.to_i}")
  end

  def insert_plaintext!(model, attrs)
    now = 1.day.ago.change(usec: 0)
    ActiveRecord::Encryption.without_encryption do
      model.insert!({workspace_id: workspace.id, user_id: user.id, created_at: now, updated_at: now}.merge(attrs))
    end
    model.order(:id).last
  end

  it "encrypts plaintext secrets of every connection without validating or touching them" do
    rows = {
      insert_plaintext!(GmailConnection, access_token: "gmail-access", refresh_token: "gmail-refresh") => %i[access_token refresh_token],
      insert_plaintext!(CalendarConnection, access_token: "cal-access", refresh_token: "cal-refresh") => %i[access_token refresh_token],
      insert_plaintext!(MailjetConnection, api_key: "mj-key", secret_key: "mj-secret", webhook_token: "mj-token") => %i[api_key secret_key],
      insert_plaintext!(StripeConnection, api_key: "not-a-stripe-key") => %i[api_key],
      insert_plaintext!(BeehiivConnection, api_key: "beehiiv-key") => %i[api_key],
      insert_plaintext!(SmtpConnection, address: "smtp.example.com", from_email: "not-an-email", password: "smtp-pass") => %i[password],
      insert_plaintext!(Webhook, url: "not a url", events: ["unknown"], secret: "hook-secret") => %i[secret]
    }
    ActiveRecord::Encryption.without_encryption { workspace.update_columns(okm_service_account_key: "okm-key") }
    rows[workspace.reload] = %i[okm_service_account_key]

    plaintext = rows.to_h { |record, columns| [record, columns.index_with { |column| raw_value(record.class, record.id, column) }] }
    updated_at = rows.keys.index_with(&:updated_at)

    expect { task.invoke }.to output(/GmailConnection: 1\n.*Workspace: 1\n/m).to_stdout

    rows.each do |record, columns|
      columns.each do |column|
        expect(raw_value(record.class, record.id, column)).not_to eq(plaintext[record][column])
        expect(record.class.find(record.id).public_send(column)).to eq(plaintext[record][column])
      end
      expect(record.class.find(record.id).updated_at).to eq(updated_at[record])
    end
  end

  it "keeps already encrypted secrets readable when run again" do
    connection = GmailConnection.create!(workspace:, user:, access_token: "access", refresh_token: "refresh")

    expect { task.invoke }.to output.to_stdout
    task.reenable
    expect { task.invoke }.to output.to_stdout

    expect(GmailConnection.find(connection.id).refresh_token).to eq("refresh")
  end
end
