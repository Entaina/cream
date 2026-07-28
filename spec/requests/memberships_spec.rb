require "rails_helper"

RSpec.describe "Memberships", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:admin) { users(:one) }
  let(:member) { users(:two) }
  let(:member_membership) { memberships(:one_member) }

  let(:workspace) { workspaces(:one) }

  before do
    sign_in_as(admin)
    patch switch_workspace_path, params: { workspace_id: workspace.id }
  end

  describe "PATCH /memberships/:id" do
    it "updates a member role" do
      patch membership_path(member_membership), params: { membership: { role: "admin" } }

      expect(response).to redirect_to(settings_team_path)
      expect(member_membership.reload.role).to eq("admin")
    end

    it "prevents demoting the last admin" do
      admin_membership = memberships(:one_one)

      patch membership_path(admin_membership), params: { membership: { role: "salesperson" } }

      expect(response).to redirect_to(settings_team_path)
      expect(admin_membership.reload.role).to eq("admin")
    end
  end

  describe "DELETE /memberships/:id" do
    it "removes a member from the workspace" do
      expect {
        delete membership_path(member_membership)
      }.to change(Membership, :count).by(-1)

      expect(response).to redirect_to(settings_team_path)
    end

    it "forbids members from removing others" do
      sign_in_as(member)
      patch switch_workspace_path, params: { workspace_id: workspaces(:one).id }

      expect {
        delete membership_path(memberships(:one_one))
      }.not_to change(Membership, :count)

      expect(response).to redirect_to(root_path)
    end
  end
end
