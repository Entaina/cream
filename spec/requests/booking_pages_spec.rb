require "rails_helper"

RSpec.describe "Booking pages calendars", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:user) { users(:one) }
  let(:workspace) { workspaces(:one) }

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:calendar_booking).and_return(true)
    sign_in_as(user)
  end

  it "returns calendars for a connected host" do
    workspace.calendar_connections.create!(
      user: user,
      email: "host@example.com",
      refresh_token: "rt",
      access_token: "at",
      expires_at: 1.hour.from_now,
      granted_scopes: "#{CalendarConnection::READONLY_SCOPE} #{CalendarConnection::EVENTS_SCOPE}"
    )
    allow(GoogleCalendar::Client).to receive(:new).and_return(
      instance_double(GoogleCalendar::Client, list_calendars: [
        { id: "primary@gmail.com", summary: "Principal", primary: true, writable: true }
      ])
    )

    get calendars_booking_pages_path, params: { host_id: user.id }

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["calendars"].first["summary"]).to eq("Principal")
  end

  it "returns error when host is not connected" do
    get calendars_booking_pages_path, params: { host_id: user.id }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body["error"]).to eq("not_connected")
  end
end
