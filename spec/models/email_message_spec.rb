require "rails_helper"

RSpec.describe EmailMessage do
  fixtures :users, :workspaces, :memberships, :companies

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }

  it "defaults to outbound direction" do
    message = workspace.email_messages.create!(
      user: user,
      record: companies(:acme),
      to_address: "alex@example.com",
      subject: "Hi",
      body: "Hello",
      status: "sent"
    )

    expect(message).to be_outbound
    expect(message).not_to be_inbound
  end

  it "supports inbound replies linked to outbound messages" do
    outbound = workspace.email_messages.create!(
      user: user,
      record: companies(:acme),
      to_address: "alex@example.com",
      subject: "Hi",
      body: "Hello",
      status: "sent",
      gmail_thread_id: "thread-1"
    )

    inbound = workspace.email_messages.create!(
      direction: "inbound",
      status: "received",
      user: user,
      record: companies(:acme),
      in_reply_to: outbound,
      from_address: "Alex <alex@example.com>",
      to_address: "me@gmail.com",
      subject: "Re: Hi",
      body: "Thanks!",
      gmail_message_id: "in-1",
      gmail_thread_id: "thread-1"
    )

    expect(inbound).to be_inbound
    expect(inbound.in_reply_to).to eq(outbound)
    expect(outbound.replies).to include(inbound)
  end

  describe "#route_via_gmail?" do
    let(:message) do
      workspace.email_messages.new(user: user, record: companies(:acme), to_address: "a@b.com", subject: "Hi", body: "Hi")
    end

    before do
      allow(CreamFeatures).to receive(:enabled?).and_call_original
      allow(CreamFeatures).to receive(:enabled?).with(:gmail_sync).and_return(true)
      workspace.gmail_connections.create!(
        user: user,
        email: "host@gmail.com",
        access_token: "at",
        refresh_token: "rt",
        expires_at: 1.hour.from_now,
        send_enabled: true,
        granted_scopes: GmailConnection::SEND_SCOPE
      )
    end

    it "returns false in development so mail goes to Mailbin" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("development"))

      expect(message.route_via_gmail?).to eq(false)
    end

    it "returns true in production when Gmail send is enabled" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))

      expect(message.route_via_gmail?).to eq(true)
    end
  end
end
