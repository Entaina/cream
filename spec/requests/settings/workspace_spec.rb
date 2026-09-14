require "rails_helper"

RSpec.describe "Settings::Workspace", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:admin) { users(:one) }
  let(:member) { users(:two) }
  let(:workspace) { workspaces(:one) }
  let(:okm_service_account_key) do
    {
      "type" => "service_account",
      "project_id" => "test-project",
      "private_key_id" => "key123",
      "private_key" => "-----BEGIN PRIVATE KEY-----\ntest\n-----END PRIVATE KEY-----\n",
      "client_email" => "okm@test.iam.gserviceaccount.com",
      "client_id" => "123456789"
    }.to_json
  end

  before do
    sign_in_as(admin)
    patch switch_workspace_path, params: { workspace_id: workspace.id }
  end

  describe "GET /settings/workspace" do
    it "shows workspace settings to admins" do
      get settings_workspace_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Settings")
      expect(response.body).to include("General")
    end

    it "forbids members from viewing workspace settings" do
      sign_in_as(member)
      patch switch_workspace_path, params: { workspace_id: workspace.id }

      get settings_workspace_path

      expect(response).to redirect_to(root_path)
    end
  end

  describe "PATCH /settings/workspace" do
    it "renames the workspace for admins" do
      patch settings_workspace_path, params: { workspace: { name: "Renamed Workspace" } }

      expect(response).to redirect_to(settings_workspace_path)
      expect(workspace.reload.name).to eq("Renamed Workspace")
    end

    it "allows admins to enable sales director for the workspace" do
      allow(CreamFeatures).to receive(:enabled?).and_call_original
      allow(CreamFeatures).to receive(:enabled?).with(:sales_director).and_return(true)

      patch settings_workspace_path, params: { workspace: { sales_director_enabled: true } }

      expect(response).to redirect_to(settings_workspace_path)
      expect(workspace.reload.sales_director_enabled?).to be(true)
    end

    it "allows admins to configure workspace feature toggles" do
      patch settings_workspace_path, params: {
        workspace: {
          reports_enabled: true,
          marketing_attribution_enabled: true,
          lead_scoring_enabled: true,
          webhooks_enabled: true,
          custom_fields_enabled: true
        }
      }

      expect(response).to redirect_to(settings_workspace_path)
      workspace.reload
      expect(workspace.reports_enabled?).to be(true)
      expect(workspace.marketing_attribution_enabled?).to be(true)
      expect(workspace.lead_scoring_enabled?).to be(true)
      expect(workspace.webhooks_enabled?).to be(true)
      expect(workspace.custom_fields_enabled?).to be(true)
    end

    it "allows admins to configure salesperson deal scope" do
      patch settings_workspace_path, params: {
        workspace: {
          salespeople_can_view_all_deals: true,
          salespeople_can_edit_all_deals: true
        }
      }

      expect(response).to redirect_to(settings_workspace_path)
      workspace.reload
      expect(workspace.salespeople_can_view_all_deals?).to be(true)
      expect(workspace.salespeople_can_edit_all_deals?).to be(true)
    end

    it "allows admins to configure OKM settings" do
      allow(CreamFeatures).to receive(:enabled?).and_call_original
      allow(CreamFeatures).to receive(:enabled?).with(:okm_chat).and_return(true)

      patch settings_workspace_path, params: {
        workspace: {
          okm_chat_enabled: true,
          okm_drive_id: "drive123",
          okm_service_account_key: okm_service_account_key
        }
      }

      expect(response).to redirect_to(settings_workspace_path)
      workspace.reload
      expect(workspace.okm_chat_enabled?).to be(true)
      expect(workspace.okm_drive_id).to eq("drive123")
      expect(workspace.okm_configured?).to be(true)
      expect(workspace.okm_service_account_client_email).to eq("okm@test.iam.gserviceaccount.com")
    end

    it "preserves the service account key when the textarea is left blank" do
      workspace.update!(
        okm_drive_id: "drive123",
        okm_service_account_key: okm_service_account_key
      )

      patch settings_workspace_path, params: {
        workspace: {
          okm_drive_id: "drive456",
          okm_service_account_key: ""
        }
      }

      expect(response).to redirect_to(settings_workspace_path)
      workspace.reload
      expect(workspace.okm_drive_id).to eq("drive456")
      expect(workspace.okm_service_account_client_email).to eq("okm@test.iam.gserviceaccount.com")
    end

    it "forbids members from updating workspace settings" do
      sign_in_as(member)
      patch switch_workspace_path, params: { workspace_id: workspace.id }

      patch settings_workspace_path, params: { workspace: { name: "Blocked" } }

      expect(response).to redirect_to(root_path)
      expect(workspace.reload.name).not_to eq("Blocked")
    end
  end
end
