require "rails_helper"

RSpec.describe MailjetConnection do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }

  def build_connection(**attrs)
    workspace.build_mailjet_connection({
      user: user,
      api_key: "mj-api-key-1234",
      secret_key: "mj-secret-5678",
      from_email: "noreply@example.com"
    }.merge(attrs))
  end

  it "generates a webhook token on create" do
    connection = build_connection
    connection.save!

    expect(connection.webhook_token).to be_present
    expect(connection.webhook_url).to include(connection.webhook_token)
  end

  it "masks stored keys" do
    connection = build_connection
    expect(connection.masked_api_key).to eq("mj-a…1234")
    expect(connection.masked_secret_key).to eq("mj-s…5678")
  end

  it "requires a valid from email" do
    connection = build_connection(from_email: "not-an-email")
    expect(connection).not_to be_valid
    expect(connection.errors[:from_email]).to be_present
  end

  it "does not send transactional mail until enabled" do
    connection = build_connection
    expect(connection.transactional?).to be(false)

    connection.transactional_enabled = true
    expect(connection.transactional?).to be(true)
  end
end
