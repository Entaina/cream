require "rails_helper"

RSpec.describe "Superadmin workspaces", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:superadmin) { users(:superadmin) }
  let(:member) { users(:one) }

  describe "GET /superadmin" do
    it "returns 404 for normal users" do
      sign_in_as(member)

      get superadmin_root_path

      expect(response).to have_http_status(:not_found)
    end

    it "lists workspaces for superadmin" do
      sign_in_as(superadmin)

      get superadmin_root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(workspaces(:one).name)
    end
  end

  describe "POST /superadmin/workspaces" do
    it "creates a workspace and assigns an existing user as admin" do
      sign_in_as(superadmin)

      expect {
        post superadmin_workspaces_path, params: {
          workspace: {
            name: "Acme Corp",
            slug: "acme-corp",
            email_domain: "acme.test",
            initial_admin_email: member.email_address,
            initial_admin_role: "admin"
          }
        }
      }.to change(Workspace, :count).by(1)

      workspace = Workspace.find_by!(slug: "acme-corp")
      expect(workspace.email_domain).to eq("acme.test")
      expect(workspace.memberships.find_by(user: member)).to be_admin
      expect(response).to redirect_to(superadmin_workspace_path(workspace))
    end

    it "sends an invitation when the admin user does not exist" do
      sign_in_as(superadmin)

      expect(InvitationMailer).to receive(:invite).and_return(double(deliver_later: true))

      expect {
        post superadmin_workspaces_path, params: {
          workspace: {
            name: "Beta Inc",
            slug: "beta-inc",
            initial_admin_email: "newadmin@beta.test",
            initial_admin_role: "admin"
          }
        }
      }.to change(Invitation, :count).by(1)

      invitation = Invitation.order(:id).last
      expect(invitation.email_address).to eq("newadmin@beta.test")
      expect(invitation.workspace.slug).to eq("beta-inc")
    end
  end

  describe "POST /superadmin/workspaces/:id/enter" do
    it "switches workspace and creates support membership" do
      sign_in_as(superadmin)
      workspace = workspaces(:two)

      post enter_superadmin_workspace_path(workspace)

      expect(response).to redirect_to(root_path)
      membership = superadmin.memberships.find_by(workspace: workspace)
      expect(membership).to be_admin
      expect(membership.superadmin_access).to be(true)
    end
  end
end
