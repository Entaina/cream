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
      expect(response.body).not_to include("Workspace settings")
    end

    it "hides management controls from members" do
      sign_in_as(member)
      patch switch_workspace_path, params: { workspace_id: workspace.id }

      get settings_team_path

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include("Invite member")
    end
  end
end
