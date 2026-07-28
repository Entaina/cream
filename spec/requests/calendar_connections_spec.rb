require "rails_helper"

RSpec.describe "Calendar connections", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:user) { users(:one) }
  let(:workspace) { workspaces(:one) }

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:calendar_booking).and_return(true)
  end

  describe "OAuth connect callback" do
    before { OmniAuth.config.test_mode = true }

    after do
      OmniAuth.config.mock_auth[:google_gmail] = nil
      OmniAuth.config.test_mode = false
    end

    it "stores Calendar tokens when calendar_mode is set" do
      sign_in_as(user)
      OmniAuth.config.mock_auth[:google_gmail] = OmniAuth::AuthHash.new(
        provider: "google_gmail", uid: "g1",
        info: OmniAuth::AuthHash::InfoHash.new(email: "host@example.com"),
        credentials: {
          token: "at", refresh_token: "rt", expires_at: 1.hour.from_now.to_i,
          scope: "email profile #{CalendarConnection::READONLY_SCOPE} #{CalendarConnection::EVENTS_SCOPE}"
        }
      )

      get "/auth/google_gmail/callback", params: { calendar_mode: "1" }

      connection = workspace.calendar_connections.find_by(user: user)
      expect(connection).to be_connected
      expect(connection.can_manage_events?).to be(true)
      expect(response).to redirect_to(calendar_connection_path)
    end
  end
end
