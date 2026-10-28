require "rails_helper"

RSpec.describe "Settings::ConnectedApps", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:user) { users(:one) }
  let(:application) do
    Doorkeeper::Application.create!(
      name: "Claude", redirect_uri: "https://claude.ai/api/mcp/auth_callback", confidential: false, scopes: "mcp"
    )
  end
  let(:other_application) do
    Doorkeeper::Application.create!(
      name: "Gmail add-on", redirect_uri: "https://script.google.com/callback", confidential: false, scopes: "api"
    )
  end
  let!(:token) do
    Doorkeeper::AccessToken.create!(application: application, resource_owner_id: user.id, scopes: "mcp", expires_in: 3600)
  end

  before { sign_in_as(user) }

  describe "GET /settings/connected_apps" do
    it "lists the OAuth apps connected by the current user" do
      get settings_connected_apps_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Claude")
    end

    it "shows an app once even when it holds several tokens" do
      Doorkeeper::AccessToken.create!(application: application, resource_owner_id: user.id, scopes: "mcp", expires_in: 3600)

      get settings_connected_apps_path

      expect(response.body.scan(">Claude<").size).to eq(1)
    end

    it "hides apps whose tokens are all revoked" do
      token.revoke

      get settings_connected_apps_path

      expect(response.body).not_to include("Claude")
    end

    it "hides apps connected only by other users" do
      Doorkeeper::AccessToken.create!(application: other_application, resource_owner_id: users(:two).id, scopes: "api")

      get settings_connected_apps_path

      expect(response.body).not_to include("Gmail add-on")
    end
  end

  describe "DELETE /settings/connected_apps/:id" do
    it "revokes every token and pending grant the user holds for the app" do
      second = Doorkeeper::AccessToken.create!(application: application, resource_owner_id: user.id, scopes: "mcp", expires_in: 3600)
      grant = Doorkeeper::AccessGrant.create!(
        application: application, resource_owner_id: user.id, scopes: "mcp", expires_in: 600,
        redirect_uri: application.redirect_uri
      )

      delete settings_connected_app_path(application)

      expect(response).to redirect_to(settings_connected_apps_path)
      expect(token.reload).to be_revoked
      expect(second.reload).to be_revoked
      expect(grant.reload).to be_revoked
    end

    it "stops the revoked token from reaching MCP" do
      plaintext = token.plaintext_token

      delete settings_connected_app_path(application)
      post mcp_url, params: initialize_payload, as: :json, headers: mcp_headers(plaintext)

      expect(response).to have_http_status(:unauthorized)
    end

    it "keeps the user's tokens for other apps" do
      kept = Doorkeeper::AccessToken.create!(application: other_application, resource_owner_id: user.id, scopes: "api")

      delete settings_connected_app_path(application)

      expect(kept.reload).not_to be_revoked
    end

    it "keeps other users' tokens for the same app" do
      other = Doorkeeper::AccessToken.create!(application: application, resource_owner_id: users(:two).id, scopes: "mcp")

      delete settings_connected_app_path(application)

      expect(other.reload).not_to be_revoked
    end

    it "returns not found for apps the user has not connected" do
      other = Doorkeeper::AccessToken.create!(application: other_application, resource_owner_id: users(:two).id, scopes: "api")

      delete settings_connected_app_path(other_application)

      expect(response).to have_http_status(:not_found)
      expect(other.reload).not_to be_revoked
    end
  end
end
