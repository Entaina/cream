require "rails_helper"

RSpec.describe InvitationMailer, type: :mailer do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:admin) { users(:one) }

  it "sends invite email with workspace name" do
    invitation = workspace.invitations.create!(
      email_address: "new@example.com",
      role: "salesperson",
      invited_by: admin
    )

    mail = described_class.invite(invitation, "plaintext-token")

    expect(mail.to).to eq(["new@example.com"])
    expect(mail.subject).to include(workspace.name)
    expect(mail.body.encoded).to include("plaintext-token")
  end
end
