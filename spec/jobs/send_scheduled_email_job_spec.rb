require "rails_helper"

RSpec.describe SendScheduledEmailJob, type: :job do
  fixtures :users, :workspaces, :memberships, :companies

  let(:workspace) { workspaces(:one) }

  def build_message(status:)
    workspace.email_messages.create!(
      user: users(:one), record: companies(:acme),
      to_address: "lead@example.com", subject: "Hi", body: "Hello", status: status,
      scheduled_at: 1.hour.from_now
    )
  end

  it "delivers a scheduled message and marks it sent" do
    message = build_message(status: "scheduled")

    expect { described_class.perform_now(message.id) }
      .to change { ActionMailer::Base.deliveries.size }.by(1)
    expect(message.reload.status).to eq("sent")
  end

  it "routes a deferred email through the user's Gmail account when connected at send time" do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:gmail_sync).and_return(true)
    workspace.gmail_connections.create!(user: users(:one), email: "me@gmail.com",
      access_token: "at", refresh_token: "rt", expires_at: 1.hour.from_now, send_enabled: true)
    sender = instance_double(GmailSender)
    allow(GmailSender).to receive(:new).and_return(sender)
    result = GmailSender::SendResult.new(
      gmail_message_id: "gm1", gmail_thread_id: "gt1", rfc822_message_id: "<msg@cream.test>"
    )
    expect(sender).to receive(:send_email).and_return(result)

    message = build_message(status: "scheduled")
    expect { described_class.perform_now(message.id) }
      .not_to change { ActionMailer::Base.deliveries.size }
    expect(message.reload.status).to eq("sent")
  end

  it "is a no-op for a message that is no longer scheduled (cancelled/sent)" do
    message = build_message(status: "sent")

    expect(RecordMailer).not_to receive(:tracked_email)
    expect { described_class.perform_now(message.id) }
      .not_to change { ActionMailer::Base.deliveries.size }
  end

  it "is a no-op when the message was deleted" do
    expect { described_class.perform_now(-1) }.not_to raise_error
  end
end
