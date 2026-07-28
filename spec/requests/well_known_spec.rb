require "rails_helper"

RSpec.describe "WellKnown", type: :request do
  describe "GET /.well-known/oauth-authorization-server" do
    it "returns oauth authorization server metadata" do
      get "/.well-known/oauth-authorization-server"

      expect(response).to have_http_status(:success)
      body = JSON.parse(response.body)
      expect(body["issuer"]).to eq(root_url.chomp("/"))
      expect(body["authorization_endpoint"]).to eq(oauth_authorization_url)
      expect(body["token_endpoint"]).to eq(oauth_token_url)
      expect(body["scopes_supported"]).to include("mcp")
      expect(body["grant_types_supported"]).to include("authorization_code")
      expect(body["code_challenge_methods_supported"]).to include("S256")
    end
  end

  describe "GET /.well-known/oauth-protected-resource" do
    it "returns oauth protected resource metadata" do
      get "/.well-known/oauth-protected-resource"

      expect(response).to have_http_status(:success)
      body = JSON.parse(response.body)
      expect(body["resource"]).to eq(mcp_url)
      expect(body["authorization_servers"]).to include(root_url.chomp("/"))
      expect(body["scopes_supported"]).to include("mcp")
    end
  end

  describe "GET /.well-known/oauth-protected-resource/mcp" do
    it "returns oauth protected resource metadata at mcp path" do
      get "/.well-known/oauth-protected-resource/mcp"

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)["resource"]).to eq(mcp_url)
    end
  end
end
