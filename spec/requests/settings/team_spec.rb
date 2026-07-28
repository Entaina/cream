require "rails_helper"

RSpec.describe "Settings::Team", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:admin) { users(:one) }
  let(:member) { users(:two) }

  let(:workspace) { workspaces(:one) }

  before do
    sign_in_as(admin)
    patch switch_workspace_path, params: { workspace_id: workspace.id }
  end

  describe "GET /settings/team" do
    it "lists members for workspace admins and members" do
      get settings_team_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include(admin.name)
      expect(response.body).to include(member.name)
    end

    it "shows management controls to admins" do
      get settings_team_path

      expect(response.body).to include("Invite member")
      expect(response.body).to include("Workspace settings")
    end

    it "hides management controls from members" do
      sign_in_as(member)
      patch switch_workspace_path, params: { workspace_id: workspace.id }

      get settings_team_path

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include("Invite member")
    end
  end

  describe "PATCH /settings/team" do
    it "renames the workspace for admins" do
      patch settings_team_path, params: { workspace: { name: "Renamed Workspace" } }

      expect(response).to redirect_to(settings_team_path)
      expect(workspaces(:one).reload.name).to eq("Renamed Workspace")
    end

    it "forbids members from updating workspace settings" do
      sign_in_as(member)
      patch switch_workspace_path, params: { workspace_id: workspace.id }

      patch settings_team_path, params: { workspace: { name: "Blocked" } }

      expect(response).to redirect_to(root_path)
      expect(workspaces(:one).reload.name).not_to eq("Blocked")
    end

    it "allows admins to enable sales director for the workspace" do
      allow(CreamFeatures).to receive(:enabled?).and_call_original
      allow(CreamFeatures).to receive(:enabled?).with(:sales_director).and_return(true)

      patch settings_team_path, params: { workspace: { sales_director_enabled: true } }

      expect(response).to redirect_to(settings_team_path)
      expect(workspaces(:one).reload.sales_director_enabled?).to be(true)
    end

    it "forbids members from enabling sales director" do
      sign_in_as(member)
      patch switch_workspace_path, params: { workspace_id: workspace.id }

      patch settings_team_path, params: { workspace: { sales_director_enabled: true } }

      expect(response).to redirect_to(root_path)
      expect(workspaces(:one).reload.sales_director_enabled?).to be(false)
    end
  end
end
