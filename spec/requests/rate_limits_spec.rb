require "rails_helper"

RSpec.describe "API rate limits", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:counter) { ActiveSupport::Cache::MemoryStore.new }
  let(:user) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let(:token) { user.api_tokens.create!(name: "Limited", workspace: workspace).plaintext_token }
  let(:other_token) { user.api_tokens.create!(name: "Other", workspace: workspace).plaintext_token }

  before do
    allow(ActionController::API.cache_store).to receive(:increment) do |*args, **options|
      counter.increment(*args, **options)
    end
  end

  def exhaust(key, limit)
    counter.increment(key, limit, expires_in: 1.minute)
  end

  def token_key(scope, plaintext)
    "rate-limit:#{scope}:token:#{Digest::SHA256.hexdigest(plaintext)}"
  end

  def bearer(plaintext)
    {"Authorization" => "Bearer #{plaintext}"}
  end

  describe "REST API" do
    it "rejects a token once it goes over the limit" do
      exhaust(token_key("api_v1", token), 599)

      get "/api/v1/people", headers: bearer(token)
      expect(response).to have_http_status(:success)

      get "/api/v1/people", headers: bearer(token)
      expect(response).to have_http_status(:too_many_requests)
    end

    it "keeps other tokens from the same IP working" do
      exhaust(token_key("api_v1", token), 600)

      get "/api/v1/people", headers: bearer(token)
      expect(response).to have_http_status(:too_many_requests)

      get "/api/v1/people", headers: bearer(other_token)
      expect(response).to have_http_status(:success)
    end

    it "shares one budget across API endpoints" do
      exhaust(token_key("api_v1", token), 600)

      get "/api/v1/pipelines", headers: bearer(token)

      expect(response).to have_http_status(:too_many_requests)
    end

    it "counts requests without a token by IP" do
      exhaust("rate-limit:api_v1:ip:127.0.0.1", 600)

      get "/api/v1/people"

      expect(response).to have_http_status(:too_many_requests)
    end
  end

  describe "MCP" do
    it "rejects a token once it goes over the limit" do
      exhaust(token_key("mcp", token), 119)

      post mcp_url, params: initialize_payload, as: :json, headers: mcp_headers(token)
      expect(response).to have_http_status(:success)

      post mcp_url, params: initialize_payload, as: :json, headers: mcp_headers(token)
      expect(response).to have_http_status(:too_many_requests)
    end

    it "keeps other tokens from the same IP working" do
      exhaust(token_key("mcp", token), 120)

      post mcp_url, params: initialize_payload, as: :json, headers: mcp_headers(token)
      expect(response).to have_http_status(:too_many_requests)

      post mcp_url, params: initialize_payload, as: :json, headers: mcp_headers(other_token)
      expect(response).to have_http_status(:success)
    end
  end

  describe "OAuth client registration" do
    let(:registration) do
      {client_name: "Claude", redirect_uris: ["https://claude.ai/api/mcp/auth_callback"]}
    end

    it "rejects an IP once it goes over the limit" do
      exhaust("rate-limit:oauth_registrations:127.0.0.1", 19)

      post oauth_register_path, params: registration, as: :json
      expect(response).to have_http_status(:created)

      post oauth_register_path, params: registration, as: :json
      expect(response).to have_http_status(:too_many_requests)
    end
  end
end
