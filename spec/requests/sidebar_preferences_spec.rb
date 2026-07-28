require "rails_helper"

RSpec.describe "Sidebar preferences", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }

  before { sign_in_as(member) }

  describe "PATCH /sidebar_preferences" do
    it "persists order and hidden keys for the current user" do
      order = %w[tasks deals dashboard people companies products]
      hidden = %w[api_tokens custom_fields]

      patch sidebar_preferences_path,
        params: { order: order, hidden: hidden },
        as: :json

      expect(response).to have_http_status(:ok)
      member.reload
      expect(member.sidebar_prefs["order"]).to eq(User.merge_sidebar_order(order, User.sidebar_default_keys))
      expect(member.sidebar_hidden).to match_array(hidden)
    end

    it "ignores unknown keys" do
      patch sidebar_preferences_path,
        params: { order: %w[dashboard unknown_key people], hidden: %w[unknown_key api_tokens] },
        as: :json

      expect(response).to have_http_status(:ok)
      member.reload
      expect(member.sidebar_prefs["order"]).not_to include("unknown_key")
      expect(member.sidebar_hidden).to eq(%w[api_tokens])
    end

    it "requires authentication" do
      delete session_path

      patch sidebar_preferences_path,
        params: { order: %w[dashboard], hidden: [] },
        as: :json

      expect(response).to redirect_to(new_session_path)
    end
  end
end
