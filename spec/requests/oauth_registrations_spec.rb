require "rails_helper"

RSpec.describe "OauthRegistrations", type: :request do
  describe "POST /oauth/register" do
    it "registers a public api client for the Gmail add-on" do
      post oauth_register_path,
        params: {
          client_name: "CReaM Gmail add-on",
          scope: "api",
          redirect_uris: ["https://script.google.com/macros/d/test/usercallback"]
        },
        as: :json

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["scope"]).to eq("api")
      expect(body["client_name"]).to eq("CReaM Gmail add-on")
    end

    it "rejects an unknown scope" do
      post oauth_register_path,
        params: {
          client_name: "Bad",
          scope: "admin",
          redirect_uris: ["https://127.0.0.1/callback"]
        },
        as: :json

      expect(response).to have_http_status(:bad_request)
      body = JSON.parse(response.body)
      expect(body["error"]).to eq("invalid_scope")
    end

    it "registers a public mcp client" do
      post oauth_register_path,
        params: {
          client_name: "Claude Desktop",
          redirect_uris: ["https://127.0.0.1/callback"]
        },
        as: :json

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["client_id"]).to be_present
      expect(body["client_name"]).to eq("Claude Desktop")
      expect(body["redirect_uris"]).to eq(["https://127.0.0.1/callback"])
      expect(body["token_endpoint_auth_method"]).to eq("none")
      expect(body["scope"]).to eq("mcp")
    end

    it "rejects registration without redirect_uris" do
      post oauth_register_path, params: {client_name: "Bad client"}, as: :json

      expect(response).to have_http_status(:bad_request)
      body = JSON.parse(response.body)
      expect(body["error"]).to eq("invalid_redirect_uri")
    end

    it "registers a client with an HTTP localhost loopback redirect" do
      post oauth_register_path,
        params: {
          client_name: "Claude Code",
          redirect_uris: ["http://localhost:53210/callback"]
        },
        as: :json

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["redirect_uris"]).to eq(["http://localhost:53210/callback"])
    end

    it "registers a client with an HTTP 127.0.0.1 loopback redirect" do
      post oauth_register_path,
        params: {
          client_name: "Claude Code",
          redirect_uris: ["http://127.0.0.1:53210/callback"]
        },
        as: :json

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["redirect_uris"]).to eq(["http://127.0.0.1:53210/callback"])
    end

    it "rejects registration with a non-loopback HTTP redirect" do
      post oauth_register_path,
        params: {
          client_name: "Bad client",
          redirect_uris: ["http://example.com/callback"]
        },
        as: :json

      expect(response).to have_http_status(:bad_request)
      body = JSON.parse(response.body)
      expect(body["error"]).to eq("invalid_client_metadata")
      invalid_app = Doorkeeper::Application.new(name: "Bad client", redirect_uri: "http://example.com/callback")
      invalid_app.valid?
      expect(body["error_description"]).to include(invalid_app.errors.full_messages_for(:redirect_uri).first)
    end
  end
end
