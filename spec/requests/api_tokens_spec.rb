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
