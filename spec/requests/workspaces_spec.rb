require "rails_helper"

RSpec.describe "Workspace switching", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:user) { users(:one) }
  let(:primary_workspace) { workspaces(:one) }
  let(:secondary_workspace) { workspaces(:two) }

  before do
    Membership.create!(user: user, workspace: secondary_workspace, role: "salesperson")
    sign_in_as(user)
  end

  describe "PATCH /workspace" do
    it "switches the active workspace" do
      patch switch_workspace_path, params: {workspace_id: secondary_workspace.id}

      expect(response).to redirect_to(root_path)
      expect(session[:workspace_id]).to eq(secondary_workspace.id)
    end

    it "rejects workspaces the user does not belong to" do
      outsider_workspace = Workspace.create!(name: "Outsider", slug: "outsider")

      patch switch_workspace_path, params: {workspace_id: outsider_workspace.id}

      expect(response).to have_http_status(:not_found)
    end
  end
end
