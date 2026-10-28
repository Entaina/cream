require "rails_helper"
require "digest"
require "base64"

RSpec.describe "OAuth tokens", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  fixtures :users, :workspaces, :memberships

  let(:user) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:redirect_uri) { "https://script.google.com/macros/d/test/usercallback" }
  let(:code_verifier) { "dBjftJeZ4CVP-mB92K28uhbUAVA0K7W4fRWhNwf6xRA" }
  let(:code_challenge) do
    Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false)
  end
  let(:application) do
    Doorkeeper::Application.create!(
      name: "Gmail add-on test",
      redirect_uri: redirect_uri,
      confidential: false,
      scopes: "api"
    )
  end

  let(:authorize_params) do
    {
      response_type: "code",
      client_id: application.uid,
      redirect_uri: redirect_uri,
      code_challenge: code_challenge,
      code_challenge_method: "S256",
      scope: "api"
    }
  end

  def authorization_code_from_consent
    sign_in_as(user)
    get "/oauth/authorize", params: authorize_params
    expect(response).to have_http_status(:ok)

    post "/oauth/authorize", params: authorize_params
    expect(response).to have_http_status(:redirect)

    uri = URI.parse(response.location)
    Rack::Utils.parse_nested_query(uri.query)["code"]
  end

  describe "POST /oauth/token" do
    before do
      Doorkeeper::AccessGrant.delete_all
      Doorkeeper::AccessToken.delete_all
    end

    it "issues tokens for a public PKCE client without client_secret" do
      code = authorization_code_from_consent
      expect(code).to be_present

      post "/oauth/token", params: {
        grant_type: "authorization_code",
        client_id: application.uid,
        redirect_uri: redirect_uri,
        code: code,
        code_verifier: code_verifier
      }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["access_token"]).to be_present
      expect(body["refresh_token"]).to be_present
      expect(body["token_type"]).to eq("Bearer")
      expect(body["scope"]).to eq("api")
    end

    it "refreshes access tokens for a public client without client_secret" do
      code = authorization_code_from_consent

      post "/oauth/token", params: {
        grant_type: "authorization_code",
        client_id: application.uid,
        redirect_uri: redirect_uri,
        code: code,
        code_verifier: code_verifier
      }
      initial = JSON.parse(response.body)
      refresh_token = initial["refresh_token"]

      post "/oauth/token", params: {
        grant_type: "refresh_token",
        client_id: application.uid,
        refresh_token: refresh_token
      }

      expect(response).to have_http_status(:ok)
      refreshed = JSON.parse(response.body)
      expect(refreshed["access_token"]).to be_present
      expect(refreshed["access_token"]).not_to eq(initial["access_token"])

      get "/api/v1/gmail/context",
        headers: {"Authorization" => "Bearer #{refreshed["access_token"]}"},
        as: :json

      expect(response).to have_http_status(:success)
      body = JSON.parse(response.body)
      expect(body["selected_workspace_id"]).to eq(workspace.id)
    end

    describe "refresh token max age" do
      let(:limit_start) { DoorkeeperRefreshTokenMaxAge::ENFORCED_FROM }

      def refresh_token_issued_at(time)
        token = Doorkeeper::AccessToken.create!(
          application: application,
          resource_owner_id: user.id,
          scopes: "api",
          expires_in: 2.hours.to_i,
          use_refresh_token: true
        )
        token.update_column(:created_at, time)
        token.plaintext_refresh_token
      end

      def refresh(refresh_token)
        post "/oauth/token", params: {grant_type: "refresh_token", client_id: application.uid, refresh_token: refresh_token}
      end

      it "rejects refresh tokens unused for more than 90 days" do
        travel_to(limit_start + 200.days) do
          refresh(refresh_token_issued_at(91.days.ago))
        end

        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)["error"]).to eq("invalid_grant")
      end

      it "still refreshes tokens used within the last 90 days" do
        travel_to(limit_start + 200.days) do
          refresh(refresh_token_issued_at(89.days.ago))
        end

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)["refresh_token"]).to be_present
      end

      it "gives tokens issued before the limit 90 days from its start" do
        travel_to(limit_start + 89.days) do
          refresh(refresh_token_issued_at(limit_start - 200.days))
        end
        expect(response).to have_http_status(:ok)

        travel_to(limit_start + 91.days) do
          refresh(refresh_token_issued_at(limit_start - 200.days))
        end
        expect(response).to have_http_status(:bad_request)
      end
    end

    it "rejects expired OAuth access tokens on the API" do
      access_token = Doorkeeper::AccessToken.create!(
        application: application,
        resource_owner_id: user.id,
        scopes: "api",
        expires_in: 1
      )

      travel 2.seconds do
        get "/api/v1/gmail/context",
          headers: {"Authorization" => "Bearer #{access_token.plaintext_token}"},
          as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
