require "rails_helper"

RSpec.describe Marketing::WebhookProcessor do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let(:person) { create_person!(workspace, email: "recipient@example.com") }
  let!(:message) do
    workspace.email_messages.create!(
      user: user,
      record: person,
      to_address: person.email,
      subject: "Hello",
      body: "<p>Hi</p>",
      marketing_send: true
    )
  end

  it "records email events from webhook payload" do
    payload = {
      "Events" => [
        { "event" => "open", "CustomID" => message.id.to_s, "time" => Time.current.iso8601 }
      ]
    }

    expect {
      described_class.process!(payload: payload)
    }.to change(EmailEvent, :count).by(1)

    expect(EmailEvent.last.event_type).to eq("open")
  end

  it "ignores events for messages outside the given workspace" do
    payload = {
      "Events" => [
        { "event" => "open", "CustomID" => message.id.to_s, "time" => Time.current.iso8601 }
      ]
    }

    expect {
      described_class.process!(payload: payload, workspace: workspaces(:two))
    }.not_to change(EmailEvent, :count)
  end

  it "suppresses addresses on hard bounces" do
    payload = {
      "Events" => [
        { "event" => "bounce", "CustomID" => message.id.to_s, "email" => person.email, "time" => Time.current.iso8601 }
      ]
    }

    described_class.process!(payload: payload)

    expect(EmailSuppression.suppressed?(workspace, person.email)).to be(true)
  end
end
