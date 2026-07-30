require "rails_helper"

RSpec.describe "Settings::Team", type: :request do
  fixtures :users, :workspaces, :memberships, :invitations

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
      expect(response.body).to include("Pending invitations")
      expect(response.body).to include("invitee@example.com")
    end

    it "hides management controls from members" do
      sign_in_as(member)
      patch switch_workspace_path, params: { workspace_id: workspace.id }

      get settings_team_path

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include("Send invitation")
      expect(response.body).not_to include("Pending invitations")
      expect(response.body).not_to include("invitee@example.com")
      expect(response.body).to include(member.name)
      expect(response.body).to include("Vendedor")
    end

    it "filters members by name or email" do
      get settings_team_path, params: { q: "User One" }

      expect(response).to have_http_status(:success)
      expect(response.body).to include(admin.name)
      expect(response.body).not_to include(member.name)
    end

    it "paginates members" do
      48.times do |index|
        user = User.create!(name: "Paged #{index}", email_address: "paged#{index}@example.com", password: "password")
        workspace.memberships.create!(user: user, role: "salesperson")
      end

      get settings_team_path, params: { page: 2 }

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Página 2 de")
    end
  end

  describe "sidebar Settings link" do
    it "shows Settings to admins" do
      get root_path

      expect(response.body).to include(settings_workspace_path)
    end

    it "hides Settings from non-admins" do
      sign_in_as(member)
      patch switch_workspace_path, params: { workspace_id: workspace.id }

      get root_path

      expect(response.body).not_to include(settings_workspace_path)
    end
  end
end
