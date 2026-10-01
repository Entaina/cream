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

  it "converts host weekly hours into the visitor timezone" do
    travel_to Time.zone.parse("2026-07-28 08:00")
    allow(client).to receive(:free_busy).and_return([])

    result = described_class.daily(
      booking_page: booking_page,
      event_type: event_type,
      date: "2026-07-28",
      timezone: "America/New_York",
      client: client
    )

    expect(result.slots).to include("04:00", "04:30", "05:00", "05:30")
    expect(result.slots).not_to include("10:00")
  end

  it "accepts a guest-zone slot that maps to a host window" do
    travel_to Time.zone.parse("2026-07-28 06:00")
    allow(client).to receive(:free_busy).and_return([])
    starts_at = ActiveSupport::TimeZone["America/New_York"].parse("2026-07-28 04:00")

    expect(
      described_class.slot_available?(
        booking_page: booking_page,
        event_type: event_type,
        starts_at: starts_at,
        timezone: "America/New_York",
        client: client
      )
    ).to be(true)
  end

  it "rejects a guest-zone slot outside the host window" do
    travel_to Time.zone.parse("2026-07-28 06:00")
    allow(client).to receive(:free_busy).and_return([])
    starts_at = ActiveSupport::TimeZone["America/New_York"].parse("2026-07-28 10:00")

    expect(
      described_class.slot_available?(
        booking_page: booking_page,
        event_type: event_type,
        starts_at: starts_at,
        timezone: "America/New_York",
        client: client
      )
    ).to be(false)
  end

  it "shows a host slot on the guest's previous calendar day when zones cross midnight" do
    travel_to Time.zone.parse("2026-07-27 12:00")
    allow(client).to receive(:free_busy).and_return([])

    result = described_class.daily(
      booking_page: booking_page,
      event_type: event_type,
      date: "2026-07-27",
      timezone: "Pacific/Honolulu",
      client: client
    )

    # Tuesday 10:00 Madrid (UTC+2) is Monday 22:00 in Honolulu (UTC-10).
    expect(result.slots).to include("22:00", "22:30", "23:00", "23:30")
  end

  it "ignores the rescheduled booking's own busy block when checking availability" do
    ignore_booking = Booking.create!(
      workspace: workspace,
      booking_page: booking_page,
      booking_event_type: event_type,
      first_name: "Ana",
      last_name: "Lopez",
      email: "ana@example.com",
      starts_at: ActiveSupport::TimeZone["Europe/Madrid"].parse("2026-07-07 10:00"),
      ends_at: ActiveSupport::TimeZone["Europe/Madrid"].parse("2026-07-07 10:30"),
      timezone: "Europe/Madrid"
    )
    busy_period = {start: ignore_booking.starts_at, end: ignore_booking.ends_at}
    allow(client).to receive(:free_busy).and_return([busy_period])

    available = described_class.slot_available?(
      booking_page: booking_page,
      event_type: event_type,
      starts_at: ignore_booking.starts_at.in_time_zone("Europe/Madrid"),
      timezone: "Europe/Madrid",
      client: client,
      ignore_booking: ignore_booking
    )

    expect(available).to be(true)
  end
end
