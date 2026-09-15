require "rails_helper"

RSpec.describe BookingAvailabilityService do
  include ActiveSupport::Testing::TimeHelpers

  fixtures :users, :workspaces, :memberships
  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let(:pipeline) { Pipeline.default_for(workspace) || Pipeline.create_default!(workspace) }
  let(:booking_page) do
    page = workspace.booking_pages.new(
      name: "Agenda",
      slug: "availability-test",
      host: user,
      pipeline: pipeline,
      timezone: "Europe/Madrid",
      booking_window_days: 60,
      calendar_ids: ["primary"]
    )
    page.event_types.build(
      slug: "video",
      name_i18n: {"es" => "Online"},
      duration_minutes: 30,
      location_type: "google_meet",
      weekly_hours: {
        "monday" => [["10:00", "12:00"]],
        "tuesday" => [["10:00", "12:00"]],
        "wednesday" => [],
        "thursday" => [],
        "friday" => [],
        "saturday" => [],
        "sunday" => []
      },
      slot_increment_minutes: 30,
      buffer_before_minutes: 0,
      buffer_after_minutes: 0,
      min_notice_hours: 0,
      visible: true
    )
    page.save!
    page
  end
  let(:event_type) { booking_page.event_types.find_by!(slug: "video") }
  let(:client) { instance_double(GoogleCalendar::Client) }

  before do
    travel_to Time.zone.parse("2026-07-01 08:00")
  end

  it "marks weekdays without configured hours as unavailable" do
    allow(client).to receive(:free_busy).and_return([])

    result = described_class.monthly(
      booking_page: booking_page,
      event_type: event_type,
      month: "2026-07",
      timezone: "Europe/Madrid",
      client: client
    )

    sunday = result.days.find { |day| day[:date] == "2026-07-26" }
    monday = result.days.find { |day| day[:date] == "2026-07-27" }

    expect(sunday[:available]).to eq(false)
    expect(monday[:available]).to eq(true)
  end

  it "returns schedule-only availability when Google client is unavailable" do
    allow(client).to receive(:free_busy).and_raise(GoogleCalendar::Error, "offline")

    result = described_class.monthly(
      booking_page: booking_page,
      event_type: event_type,
      month: "2026-07",
      timezone: "Europe/Madrid",
      client: client
    )

    monday = result.days.find { |day| day[:date] == "2026-07-27" }
    expect(monday[:available]).to eq(true)
    expect(result.warning).to eq("offline")
  end

  it "does not call Google when client is nil" do
    result = described_class.monthly(
      booking_page: booking_page,
      event_type: event_type,
      month: "2026-07",
      timezone: "Europe/Madrid",
      client: nil
    )

    expect(result.days).to be_present
    expect(result.warning).to be_nil
  end

  it "excludes slots overlapping busy periods" do
    travel_to Time.zone.parse("2026-07-28 08:00")
    zone = ActiveSupport::TimeZone["Europe/Madrid"]
    busy_start = zone.parse("2026-07-28 10:00")
    allow(client).to receive(:free_busy).and_return([{start: busy_start, end: busy_start + 1.hour}])

    result = described_class.daily(
      booking_page: booking_page,
      event_type: event_type,
      date: "2026-07-28",
      timezone: "Europe/Madrid",
      client: client
    )

    expect(result.slots).to include("11:00")
    expect(result.slots).not_to include("10:00", "10:30")
  end
end
