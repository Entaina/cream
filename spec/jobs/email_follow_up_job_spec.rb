require "rails_helper"

RSpec.describe EmailFollowUpJob, type: :job do
  fixtures :users, :workspaces, :memberships, :companies

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }

  def message(**attrs)
    workspace.email_messages.create!({
      user: user, record: companies(:acme),
      to_address: "lead@example.com", subject: "Hi", body: "Hello", status: "sent"
    }.merge(attrs))
  end

  it "notifies the sender when a sent email still awaits a reply" do
    msg = message(follow_up_at: 2.days.from_now)

    expect { described_class.perform_now(msg.id) }
      .to change { user.notifications.where(kind: "email_followup").count }.by(1)
  end

  it "is a no-op when the email was marked replied" do
    msg = message(follow_up_at: 2.days.from_now, replied_at: Time.current)

    expect { described_class.perform_now(msg.id) }.not_to change(Notification, :count)
  end

  it "is a no-op when the email is still scheduled" do
    msg = message(status: "scheduled", scheduled_at: 1.hour.from_now, follow_up_at: 2.days.from_now)

    expect { described_class.perform_now(msg.id) }.not_to change(Notification, :count)
  end

  it "is a no-op when the message was deleted" do
    expect { described_class.perform_now(-1) }.not_to raise_error
  end
end
