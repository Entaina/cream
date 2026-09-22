require "rails_helper"

RSpec.describe Invitation, type: :model do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:inviter) { users(:one) }

  describe "validations" do
    it "creates a pending invitation with token" do
      invitation = workspace.invitations.build(
        email_address: "new@example.com",
        role: "salesperson",
        invited_by: inviter
      )

      expect(invitation.save).to be true
      expect(invitation.plaintext_token).to start_with("inv_")
      expect(invitation.pending?).to be true
    end

    it "rejects inviting an existing member" do
      invitation = workspace.invitations.build(
        email_address: users(:two).email_address,
        role: "salesperson",
        invited_by: inviter
      )

      expect(invitation).not_to be_valid
      expect(invitation.errors[:email_address]).to include(I18n.t("activerecord.errors.messages.invitation_already_member"))
    end

    it "rejects duplicate pending invitations" do
      workspace.invitations.create!(
        email_address: "dup@example.com",
        role: "salesperson",
        invited_by: inviter
      )

      duplicate = workspace.invitations.build(
        email_address: "dup@example.com",
        role: "admin",
        invited_by: inviter
      )

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:email_address]).to include(I18n.t("activerecord.errors.messages.invitation_pending"))
    end
  end

  describe "#accept_for!" do
    it "creates membership and marks invitation accepted" do
      invitation = workspace.invitations.create!(
        email_address: "joiner@example.com",
        role: "admin",
        invited_by: inviter
      )
      user = User.create!(
        name: "Joiner",
        email_address: "joiner@example.com",
        password: "password123"
      )

      invitation.accept_for!(user)

      expect(invitation.accepted?).to be true
      membership = workspace.memberships.find_by(user: user)
      expect(membership.role).to eq("admin")
    end
  end
end
