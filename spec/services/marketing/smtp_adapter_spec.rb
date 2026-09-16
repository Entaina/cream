require "rails_helper"

RSpec.describe Marketing::Esp::SmtpAdapter do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let(:person) { create_person!(workspace, email: "esp@example.com") }
  let(:message) do
    workspace.email_messages.create!(
      user: user,
      record: person,
      to_address: person.email,
      subject: "Hi",
      body: "<p>Hi</p>",
      marketing_send: true
    )
  end
  let(:mailer) { instance_double(ActionMailer::MessageDelivery, deliver_now: true) }

  before do
    allow(RecordMailer).to receive(:tracked_email).with(message: message).and_return(mailer)
  end

  it "records sent when local delivery succeeds" do
    expect(described_class.new(message).deliver!).to be(true)
    expect(EmailEvent.last.event_type).to eq("sent")
    expect(message.email_events.where(event_type: "delivered")).to be_empty
  end

  it "records blocked when local delivery fails" do
    allow(mailer).to receive(:deliver_now).and_raise(StandardError, "SMTP down")

    expect(described_class.new(message).deliver!).to be(false)
    expect(EmailEvent.last.event_type).to eq("blocked")
  end
end
