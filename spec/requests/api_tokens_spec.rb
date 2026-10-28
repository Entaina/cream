require "rails_helper"

RSpec.describe "ApiTokens", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:user) { users(:one) }

  before { sign_in_as(user) }

  describe "GET /api_tokens" do
    it "requires authentication" do
      sign_out
      get api_tokens_path

      expect(response).to redirect_to(new_session_path)
    end

    it "lists user tokens" do
      user.api_tokens.create!(name: "Existing", workspace: workspaces(:one))

      get api_tokens_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Existing")
    end
  end

  describe "POST /api_tokens" do
    it "creates a token" do
      expect {
        post api_tokens_path, params: {name: "My client"}
      }.to change { user.api_tokens.count }.by(1)

      expect(response).to redirect_to(api_tokens_path)
      follow_redirect!
      expect(response.body).to include("cream_")
      expect(user.api_tokens.last).to have_attributes(token_scope: "write", expires_at: nil)
    end

    it "creates a read-only token with an expiry" do
      post api_tokens_path, params: {name: "Reader", token_scope: "read", expires_in_days: "30"}

      token = user.api_tokens.last
      expect(token.token_scope).to eq("read")
      expect(token.expires_at).to be_within(1.minute).of(30.days.from_now)
    end

    it "rejects an unknown permission" do
      expect {
        post api_tokens_path, params: {name: "Admin", token_scope: "admin"}
      }.not_to change(ApiToken, :count)

      expect(response).to redirect_to(api_tokens_path)
    end

    it "ignores expiry periods that are not offered" do
      post api_tokens_path, params: {name: "Odd", expires_in_days: "5"}

      expect(user.api_tokens.last.expires_at).to be_nil
    end
  end

  describe "listing permissions and expiry" do
    it "shows each token's permission and expiry date" do
      user.api_tokens.create!(name: "Reader", workspace: workspaces(:one), token_scope: "read", expires_at: 10.days.from_now)

      get api_tokens_path

      expect(response.body).to include(I18n.t("integrations.api_tokens.scopes.read"))
      expect(response.body).to include(I18n.t("integrations.api_tokens.expires"))
    end
  end

  describe "DELETE /api_tokens/:id" do
    it "destroys a token" do
      token = user.api_tokens.create!(name: "Revoke me", workspace: workspaces(:one))

      expect {
        delete api_token_path(token)
      }.to change { user.api_tokens.count }.by(-1)

      expect(response).to redirect_to(api_tokens_path)
    end

    it "cannot destroy another users token" do
      other_token = users(:two).api_tokens.create!(name: "Other", workspace: workspaces(:two))

      expect {
        delete api_token_path(other_token)
      }.not_to change(ApiToken, :count)

      expect(response).to have_http_status(:not_found)
    end
  end
end
