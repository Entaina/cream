require "rails_helper"

RSpec.describe GoogleCalendar::Client do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let(:connection) do
    workspace.calendar_connections.create!(
      user: user,
      email: "host@example.com",
      refresh_token: "rt",
      access_token: "at",
      expires_at: 1.hour.from_now,
      granted_scopes: CalendarConnection::EVENTS_SCOPE
    )
  end
  let(:client) { described_class.new(connection) }

  describe "#list_calendars" do
    it "returns writable and readable calendars from Google" do
      body = {
        items: [
          { id: "primary@gmail.com", summary: "Principal", primary: true, accessRole: "owner" },
          { id: "team@group.calendar.google.com", summary: "Equipo", accessRole: "reader" }
        ]
      }.to_json
      response = instance_double(Net::HTTPSuccess, body: body, is_a?: true)
      allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:start).and_yield(http)
      allow(http).to receive(:request).and_return(response)

      calendars = client.list_calendars

      expect(calendars.size).to eq(2)
      expect(calendars.first).to include(id: "primary@gmail.com", primary: true, writable: true)
      expect(calendars.last).to include(id: "team@group.calendar.google.com", writable: false)
    end
  end
end
