require "rails_helper"

RSpec.describe Marketing::Esp::Client do
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

  it "uses Mailjet when the workspace has a connection" do
    workspace.create_mailjet_connection!(
      user: user,
      api_key: "api-key-xxxx",
      secret_key: "secret-yyyy",
      from_email: "noreply@example.com"
    )

    expect(described_class.adapter_class_for(message)).to eq(Marketing::Esp::MailjetAdapter)
  end

  it "falls back to SMTP when the workspace has no Mailjet connection" do
    expect(described_class.adapter_class_for(message)).to eq(Marketing::Esp::SmtpAdapter)
  end
end
