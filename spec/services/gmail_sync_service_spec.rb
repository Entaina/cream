require "rails_helper"

RSpec.describe GmailSyncService do
  fixtures :users, :workspaces, :memberships, :companies

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let(:connection) do
    workspace.gmail_connections.create!(
      user: user, email: "me@gmail.com",
      access_token: "at", refresh_token: "rt", expires_at: 1.hour.from_now,
      sync_enabled: true,
      granted_scopes: "#{GmailConnection::SEND_SCOPE} #{GmailConnection::METADATA_SCOPE}"
    )
  end
  let(:reader) { instance_double(GmailReader) }

  def outbound_message(**attrs)
    workspace.email_messages.create!({
      user: user,
      record: companies(:acme),
      to_address: "alex@example.com",
      subject: "Proposal",
      body: "Hello",
      status: "sent",
      gmail_message_id: "gm-out",
      gmail_thread_id: "thread-1",
      rfc822_message_id: "<orig@cream.test>"
    }.merge(attrs))
  end

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:notifications).and_return(true)
  end

  it "marks a reply matched by thread id" do
    message = outbound_message
    metadata = GmailReader::Metadata.new(
      id: "in-1", thread_id: "thread-1", label_ids: ["INBOX"],
      from: "Alex <alex@example.com>", subject: "Re: Proposal",
      in_reply_to: nil, references: nil, message_id: "<reply@example.com>",
      internal_date: 1.hour.ago.to_i * 1000
    )

    allow(reader).to receive(:get_thread_metadata).with("thread-1").and_return([metadata])
    allow(reader).to receive(:list_recent_message_ids).and_return([])

    expect {
      described_class.new(connection: connection, reader: reader).sync!
    }.to change { message.reload.replied? }.from(false).to(true)
      .and change { user.notifications.where(kind: "email_replied").count }.by(1)
      .and change { companies(:acme).activities.where(action: "email_replied").count }.by(1)

    expect(connection.reload.last_synced_at).to be_present
  end

  it "marks a reply matched by In-Reply-To when thread id differs" do
    message = outbound_message(gmail_thread_id: "other-thread")
    metadata = GmailReader::Metadata.new(
      id: "in-2", thread_id: "thread-2", label_ids: ["INBOX"],
      from: "Alex <alex@example.com>", subject: "Re: Proposal",
      in_reply_to: "<orig@cream.test>", references: "<orig@cream.test>",
      message_id: "<reply2@example.com>",
      internal_date: 1.hour.ago.to_i * 1000
    )

    allow(reader).to receive(:get_thread_metadata).with("other-thread").and_return([])
    allow(reader).to receive(:list_recent_message_ids).and_return(["in-2"])
    allow(reader).to receive(:get_metadata).with("in-2").and_return(metadata)

    described_class.new(connection: connection, reader: reader).sync!

    expect(message.reload).to be_replied
  end

  it "does not mark messages sent by the connected account" do
    message = outbound_message
    metadata = GmailReader::Metadata.new(
      id: "sent-1", thread_id: "thread-1", label_ids: ["SENT"],
      from: "me@gmail.com", subject: "Proposal",
      in_reply_to: nil, references: nil, message_id: "<sent@cream.test>",
      internal_date: 1.hour.ago.to_i * 1000
    )

    allow(reader).to receive(:get_thread_metadata).with("thread-1").and_return([metadata])
    allow(reader).to receive(:list_recent_message_ids).and_return([])

    described_class.new(connection: connection, reader: reader).sync!

    expect(message.reload).not_to be_replied
  end

  it "is idempotent for already replied messages" do
    message = outbound_message(replied_at: 1.hour.ago)
    allow(reader).to receive(:get_thread_metadata).with("thread-1").and_return([])
    allow(reader).to receive(:list_recent_message_ids).and_return([])

    expect {
      described_class.new(connection: connection, reader: reader).sync!
    }.not_to change { message.reload.replied_at }
  end

  it "returns false when sync is disabled" do
    connection.update!(sync_enabled: false)
    allow(reader).to receive(:get_thread_metadata)
    allow(reader).to receive(:list_recent_message_ids)

    expect(described_class.new(connection: connection, reader: reader).sync!).to be(false)
    expect(reader).not_to have_received(:list_recent_message_ids)
  end

  it "returns false when metadata scope is not granted" do
    connection.update!(granted_scopes: GmailConnection::SEND_SCOPE)
    allow(reader).to receive(:get_thread_metadata)
    allow(reader).to receive(:list_recent_message_ids)

    expect(described_class.new(connection: connection, reader: reader).sync!).to be(false)
    expect(reader).not_to have_received(:list_recent_message_ids)
  end

  context "with full reply logging" do
    let(:full_connection) do
      connection.tap do |c|
        c.update!(granted_scopes: "#{GmailConnection::SEND_SCOPE} #{GmailConnection::READONLY_SCOPE}")
      end
    end

    def full_message(**attrs)
      GmailReader::FullMessage.new(
        id: "in-full",
        thread_id: "thread-1",
        label_ids: ["INBOX"],
        from: "Alex <alex@example.com>",
        subject: "Re: Proposal",
        snippet: "Thanks!",
        body_text: "Thanks for the proposal.",
        message_id: "<reply@example.com>",
        date: "Mon, 1 Jul 2026 10:00:00 +0200",
        **attrs
      )
    end

    it "creates an inbound email with body when readonly scope is granted" do
      outbound = outbound_message
      metadata = GmailReader::Metadata.new(
        id: "in-full", thread_id: "thread-1", label_ids: ["INBOX"],
        from: "Alex <alex@example.com>", subject: "Re: Proposal",
        in_reply_to: nil, references: nil, message_id: "<reply@example.com>",
        internal_date: 1.hour.ago.to_i * 1000
      )

      allow(reader).to receive(:get_thread_metadata).with("thread-1").and_return([metadata])
      allow(reader).to receive(:list_recent_message_ids).and_return([])
      allow(reader).to receive(:get_full).with("in-full").and_return(full_message)

      expect {
        described_class.new(connection: full_connection, reader: reader).sync!
      }.to change { workspace.email_messages.inbound.count }.by(1)

      inbound = workspace.email_messages.inbound.last
      expect(inbound.body).to eq("Thanks for the proposal.")
      expect(inbound.from_address).to include("alex@example.com")
      expect(inbound.in_reply_to).to eq(outbound)
      expect(inbound.status).to eq("received")
    end

    it "does not duplicate inbound messages on repeated sync" do
      outbound_message
      metadata = GmailReader::Metadata.new(
        id: "in-full", thread_id: "thread-1", label_ids: ["INBOX"],
        from: "Alex <alex@example.com>", subject: "Re: Proposal",
        in_reply_to: nil, references: nil, message_id: "<reply@example.com>",
        internal_date: 1.hour.ago.to_i * 1000
      )

      allow(reader).to receive(:get_thread_metadata).with("thread-1").and_return([metadata])
      allow(reader).to receive(:list_recent_message_ids).and_return([])
      allow(reader).to receive(:get_full).with("in-full").and_return(full_message)

      service = described_class.new(connection: full_connection, reader: reader)
      service.sync!
      expect { service.sync! }.not_to change { workspace.email_messages.inbound.count }
    end

    it "does not create inbound messages without readonly scope" do
      outbound_message
      metadata = GmailReader::Metadata.new(
        id: "in-full", thread_id: "thread-1", label_ids: ["INBOX"],
        from: "Alex <alex@example.com>", subject: "Re: Proposal",
        in_reply_to: nil, references: nil, message_id: "<reply@example.com>",
        internal_date: 1.hour.ago.to_i * 1000
      )

      allow(reader).to receive(:get_thread_metadata).with("thread-1").and_return([metadata])
      allow(reader).to receive(:list_recent_message_ids).and_return([])
      allow(reader).to receive(:get_full)

      expect {
        described_class.new(connection: connection, reader: reader).sync!
      }.not_to change { workspace.email_messages.inbound.count }

      expect(reader).not_to have_received(:get_full)
    end
  end
end
