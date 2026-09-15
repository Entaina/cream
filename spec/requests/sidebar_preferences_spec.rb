require "rails_helper"

RSpec.describe "Sidebar preferences", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }

  before { sign_in_as(member) }

  describe "PATCH /sidebar_preferences" do
    it "persists order and hidden keys for the current user" do
      order = %w[tasks deals dashboard people companies]
      hidden = %w[api_tokens custom_fields]

      patch sidebar_preferences_path,
        params: {order: order, hidden: hidden},
        as: :json

      expect(response).to have_http_status(:ok)
      member.reload
      expect(member.sidebar_prefs["order"]).to eq(User.merge_sidebar_order(order, User.sidebar_default_keys(admin: true)))
      expect(member.sidebar_hidden).to match_array(hidden)
    end

    it "merges order within groups without crossing them" do
      order = %w[marketing_segments marketing_campaigns tasks deals dashboard people companies deals tasks]

      patch sidebar_preferences_path,
        params: {order: order, hidden: []},
        as: :json

      member.reload
      merged = member.sidebar_prefs["order"]
      daily = merged.select { |key| SidebarMenu.group_for(key) == :daily }
      marketing = merged.select { |key| SidebarMenu.group_for(key) == :marketing }

      expect(daily.first(2)).to eq(%w[tasks deals])
      expect(marketing.first(2)).to eq(%w[marketing_segments marketing_campaigns])
    end

    it "ignores unknown keys" do
      patch sidebar_preferences_path,
        params: {order: %w[dashboard unknown_key people], hidden: %w[unknown_key api_tokens]},
        as: :json

      expect(response).to have_http_status(:ok)
      member.reload
      expect(member.sidebar_prefs["order"]).not_to include("unknown_key")
      expect(member.sidebar_hidden).to eq(%w[api_tokens])
    end

    it "strips settings keys for non-admin users" do
      sign_in_as(users(:two))
      patch switch_workspace_path, params: {workspace_id: workspaces(:one).id}

      patch sidebar_preferences_path,
        params: {order: %w[products dashboard tasks], hidden: %w[pipelines api_tokens]},
        as: :json

      expect(response).to have_http_status(:ok)
      users(:two).reload
      expect(users(:two).sidebar_prefs["order"]).not_to include("products", "pipelines")
      expect(users(:two).sidebar_hidden).to eq(%w[api_tokens])
    end

    it "requires authentication" do
      delete session_path

      patch sidebar_preferences_path,
        params: {order: %w[dashboard], hidden: []},
        as: :json

      expect(response).to redirect_to(new_session_path)
    end
  end
end
