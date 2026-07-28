require "rails_helper"

RSpec.describe SendViaGmailJob, type: :request do
  fixtures :users, :workspaces, :memberships, :companies

  let(:workspace) { workspaces(:one) }

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:gmail_sync).and_return(true)
  end

  def message
    workspace.email_messages.create!(user: users(:one), record: companies(:acme),
      to_address: "x@y.com", subject: "Hi", body: "Hello", status: "sent")
  end

  def connect!(send_enabled:)
    workspace.gmail_connections.create!(user: users(:one), email: "me@gmail.com",
      access_token: "at", refresh_token: "rt", expires_at: 1.hour.from_now, send_enabled: send_enabled,
      granted_scopes: GmailConnection::SEND_SCOPE)
  end

  it "sends through Gmail when connected and enabled, with the rendered HTML body" do
    connect!(send_enabled: true)
    sender = instance_double(GmailSender)
    allow(GmailSender).to receive(:new).and_return(sender)
    result = GmailSender::SendResult.new(
      gmail_message_id: "gm1", gmail_thread_id: "gt1", rfc822_message_id: "<msg@cream.test>"
    )

    expect(sender).to receive(:send_email) do |**kwargs|
      expect(kwargs[:to]).to eq("x@y.com")
      expect(kwargs[:subject]).to eq("Hi")
      expect(kwargs[:html]).to be_present
      expect(kwargs[:html]).to include("Hello")
      expect(kwargs[:attachments]).to eq([])
      result
    end
    msg = message
    expect { described_class.perform_now(msg.id) }.not_to change { ActionMailer::Base.deliveries.size }
    msg.reload
    expect(msg.status).to eq("sent")
    expect(msg.gmail_message_id).to eq("gm1")
    expect(msg.gmail_thread_id).to eq("gt1")
    expect(msg.rfc822_message_id).to eq("<msg@cream.test>")
    expect(companies(:acme).activities.where(action: "email_sent").count).to eq(1)
  end

  it "falls back to SMTP and marks sent when Gmail sending is not enabled" do
    connect!(send_enabled: false)
    msg = message

    expect { described_class.perform_now(msg.id) }.to change { ActionMailer::Base.deliveries.size }.by(1)
    expect(msg.reload.status).to eq("sent")
  end

  it "marks the message failed when the Gmail API fails, without sending over SMTP" do
    connect!(send_enabled: true)
    allow_any_instance_of(GmailSender).to receive(:send_email).and_raise(GmailSender::Error, "boom")
    msg = message

    expect { described_class.perform_now(msg.id) }.not_to change { ActionMailer::Base.deliveries.size }
    expect(msg.reload.status).to eq("failed")
  end

  it "passes attachments to GmailSender when the message has files" do
    connect!(send_enabled: true)
    sender = instance_double(GmailSender)
    allow(GmailSender).to receive(:new).and_return(sender)
    result = GmailSender::SendResult.new(
      gmail_message_id: "gm1", gmail_thread_id: "gt1", rfc822_message_id: "<msg@cream.test>"
    )
    msg = message
    msg.attachments.attach(io: StringIO.new("file content"), filename: "test.txt", content_type: "text/plain")

    expect(sender).to receive(:send_email) do |**kwargs|
      expect(kwargs[:attachments].size).to eq(1)
      expect(kwargs[:attachments].first[:filename]).to eq("test.txt")
      result
    end

    described_class.perform_now(msg.id)
  end

  it "attaches files when falling back to SMTP" do
    connect!(send_enabled: false)
    msg = message
    msg.attachments.attach(io: StringIO.new("file content"), filename: "test.txt", content_type: "text/plain")

    described_class.perform_now(msg.id)

    delivery = ActionMailer::Base.deliveries.last
    expect(delivery.attachments.map(&:filename)).to include(match(/test\.txt/))
  end
end
