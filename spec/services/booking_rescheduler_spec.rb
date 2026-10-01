require "rails_helper"

RSpec.describe BookingRescheduler, type: :service do
  include ActiveSupport::Testing::TimeHelpers

  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let(:pipeline) { Pipeline.default_for(workspace) || Pipeline.create_default!(workspace) }
  let(:booking_page) do
    page = workspace.booking_pages.new(
      name: "Agenda",
      slug: "rescheduler-test",
      host: user,
      pipeline: pipeline,
      timezone: "Europe/Madrid",
      calendar_ids: ["primary"]
    )
    page.event_types.build(
      slug: "video",
      name_i18n: {"es" => "Online"},
      duration_minutes: 30,
      location_type: "google_meet",
      weekly_hours: BookingEventType::DEFAULT_WEEKLY_HOURS,
      slot_increment_minutes: 15,
      min_notice_hours: 0,
      visible: true
    )
    page.save!
    page
  end
  let(:event_type) { booking_page.event_types.first }
  let(:client) { instance_double(GoogleCalendar::Client) }
  let(:booking) do
    Booking.create!(
      workspace: workspace,
      booking_page: booking_page,
      booking_event_type: event_type,
      first_name: "Ana",
      last_name: "Lopez",
      email: "ana@example.com",
      starts_at: Time.zone.parse("2026-07-28 10:00"),
      ends_at: Time.zone.parse("2026-07-28 10:30"),
      timezone: "Europe/Madrid",
      google_event_id: "evt1"
    )
  end

  before { travel_to Time.zone.parse("2026-07-01 08:00") }

  it "updates the booking and google event when the slot is available" do
    allow(client).to receive(:free_busy).and_return([
      {start: booking.starts_at, end: booking.ends_at}
    ])
    expect(client).to receive(:update_event).with(
      hash_including(calendar_id: "primary", event_id: "evt1")
    ).and_return({})
    expect(BookingConfirmationEmail).to receive(:call)

    result = described_class.call(
      booking: booking,
      params: {"datetime" => "2026-07-28T11:00:00", "timezone" => "Europe/Madrid"},
      client: client
    )

    madrid = ActiveSupport::TimeZone["Europe/Madrid"]
    expect(result.booking.starts_at.in_time_zone(madrid).strftime("%Y-%m-%d %H:%M")).to eq("2026-07-28 11:00")
  end
end
