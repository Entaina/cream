require "rails_helper"

RSpec.describe "Invitations", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:admin) { users(:one) }
  let(:member) { users(:two) }
  let(:workspace) { workspaces(:one) }

  before do
    sign_in_as(admin)
    patch switch_workspace_path, params: {workspace_id: workspace.id}
    allow(InvitationMailer).to receive_message_chain(:invite, :deliver_later)
  end

  describe "POST /invitations" do
    it "creates an invitation as admin" do
      expect {
        post invitations_path, params: {
          invitation: {email_address: "newperson@example.com", role: "salesperson"}
        }
      }.to change(Invitation, :count).by(1)

      expect(response).to redirect_to(settings_team_path)
      expect(InvitationMailer).to have_received(:invite)
    end

    it "forbids members from creating invitations" do
      sign_in_as(member)
      patch switch_workspace_path, params: {workspace_id: workspace.id}

      expect {
        post invitations_path, params: {
          invitation: {email_address: "blocked@example.com", role: "salesperson"}
        }
      }.not_to change(Invitation, :count)

      expect(response).to redirect_to(root_path)
    end
  end

  describe "DELETE /invitations/:id" do
    it "revokes a pending invitation" do
      invitation = workspace.invitations.create!(
        email_address: "revoke@example.com",
        role: "salesperson",
        invited_by: admin
      )

      expect {
        delete invitation_path(invitation)
      }.to change(Invitation, :count).by(-1)

      expect(response).to redirect_to(settings_team_path)
    end
  end
end
