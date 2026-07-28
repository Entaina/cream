require "rails_helper"

RSpec.describe "InvitationAccepts", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:admin) { users(:one) }

  def create_invitation(email: "brandnew@example.com", role: "salesperson")
    workspace.invitations.create!(email_address: email, role: role, invited_by: admin)
  end

  describe "GET /invitations/accept/:token" do
    it "shows registration form for a new user" do
      invitation = create_invitation

      get accept_invitation_path(token: invitation.plaintext_token)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Create your account")
      expect(response.body).to include(invitation.email_address)
    end

    it "redirects for invalid tokens" do
      get accept_invitation_path(token: "inv_invalid")

      expect(response).to redirect_to(new_session_path)
    end
  end

  describe "POST /invitations/accept/:token" do
    it "creates a user and membership for a new invitee" do
      invitation = create_invitation

      expect {
        post accept_invitation_path(token: invitation.plaintext_token), params: {
          user: {
            name: "Brand New",
            password: "password123",
            password_confirmation: "password123"
          }
        }
      }.to change(User, :count).by(1)
        .and change { workspace.memberships.count }.by(1)

      expect(response).to redirect_to(root_path)
      expect(invitation.reload.accepted?).to be true
      expect(User.find_by(email_address: "brandnew@example.com").workspaces).to include(workspace)
    end

    it "accepts invitation for a signed-in matching user" do
      invitation = create_invitation(email: users(:outsider).email_address)
      sign_in_as(users(:outsider))

      expect {
        post accept_invitation_path(token: invitation.plaintext_token)
      }.to change { workspace.memberships.where(user: users(:outsider)).count }.by(1)

      expect(response).to redirect_to(root_path)
      expect(invitation.reload.accepted?).to be true
    end
  end
end
