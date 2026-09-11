require "rails_helper"

RSpec.describe "OAuth authorization", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:user) { users(:one) }
  let(:redirect_uri) { "https://claude.ai/api/mcp/auth_callback" }
  let(:application) do
    Doorkeeper::Application.create!(
      name: "Claude",
      redirect_uri: redirect_uri,
      confidential: false,
      scopes: "mcp"
    )
  end

  # Doorkeeper's controllers inherit from ApplicationController, which runs
  # Pundit's `verify_authorized` after_action. They must be exempt from it,
  # otherwise the OAuth flow used by MCP clients returns 500.
  describe "GET /oauth/authorize" do
    let(:params) do
      {
        response_type: "code",
        client_id: application.uid,
        redirect_uri: redirect_uri,
        code_challenge: "7pM54dwJF36BrPuwtEp8IjTetCtQzg2rNQIdV3Vm_bY",
        code_challenge_method: "S256",
        scope: "mcp"
      }
    end

    before do
      Doorkeeper::Application.delete_all
      Doorkeeper::AccessGrant.delete_all
      Doorkeeper::AccessToken.delete_all
    end

    it "renders the consent screen for a signed-in user" do
      sign_in_as(user)

      get "/oauth/authorize", params: params

      expect(response).to have_http_status(:ok), -> { "redirected to #{response.location}" }
      expect(response.body).to include(I18n.t("doorkeeper.authorizations.new.title"))
      expect(response.body).to include("btn-primary")
      expect(response.body).to include("tailwind")
      expect(response.body).not_to include("doorkeeper/application")
      expect(response.body).not_to include("btn btn-success")
    end

    it "redirects to login when there is no session" do
      get "/oauth/authorize", params: params

      expect(response).to redirect_to(new_session_url)
    end

    context "with an HTTP localhost loopback redirect" do
      let(:redirect_uri) { "http://localhost:53210/callback" }

      it "renders the consent screen for a signed-in user" do
        sign_in_as(user)

        get "/oauth/authorize", params: params

        expect(response).to have_http_status(:ok), -> { "redirected to #{response.location}" }
        expect(response.body).to include(I18n.t("doorkeeper.authorizations.new.title"))
      end
    end
  end
end
