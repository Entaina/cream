require "rails_helper"

RSpec.describe "Theme preferences", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }

  before { sign_in_as(member) }

  describe "PATCH /theme_preference" do
    User::THEMES.each do |theme|
      it "persists the #{theme} theme for the current user" do
        patch theme_preference_path, params: { theme: theme }, as: :json

        expect(response).to have_http_status(:ok)
        expect(member.reload.theme).to eq(theme)
      end
    end

    it "rejects unknown themes" do
      member.update!(theme: "dark")

      patch theme_preference_path, params: { theme: "purple" }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(member.reload.theme).to eq("dark")
    end

    it "requires authentication" do
      delete session_path

      patch theme_preference_path, params: { theme: "dark" }, as: :json

      expect(response).to redirect_to(new_session_path)
    end
  end

  describe "layout" do
    it "renders the user theme on the html element" do
      member.update!(theme: "dark")

      get root_path

      expect(response.body).to include('data-theme="dark"')
    end

    it "renders system theme for unauthenticated pages" do
      delete session_path

      get new_session_path

      expect(response.body).to include('data-theme="system"')
    end
  end
end
