require "rails_helper"

RSpec.describe BookingCreator, type: :service do
  include ActiveSupport::Testing::TimeHelpers

  fixtures :users, :workspaces, :memberships
  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let(:pipeline) { Pipeline.default_for(workspace) || Pipeline.create_default!(workspace) }
  let(:booking_page) do
    page = workspace.booking_pages.new(
      name: "Agenda",
      slug: "creator-test",
      host: user,
      pipeline: pipeline,
      timezone: "Europe/Madrid",
      calendar_ids: [ "primary" ]
    )
    page.event_types.build(
      slug: "video",
      name_i18n: { "es" => "Online" },
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
  let(:event_type) { booking_page.event_types.find_by!(slug: "video") }
  let(:client) { instance_double(GoogleCalendar::Client) }
  let(:request) { instance_double(ActionDispatch::Request, remote_ip: "127.0.0.1", user_agent: "rspec") }

  before do
    travel_to Time.zone.parse("2026-07-28 08:00")
    allow(BookingAvailabilityService).to receive(:slot_available?).and_return(true)
    allow(client).to receive(:create_event).and_return(
      "id" => "evt1",
      "htmlLink" => "https://calendar.google.com/event/1",
      "conferenceData" => {
        "entryPoints" => [ { "entryPointType" => "video", "uri" => "https://meet.google.com/abc" } ]
      }
    )
  end

  it "creates booking and CRM records" do
    result = described_class.call(
      booking_page: booking_page,
      event_type: event_type,
      params: {
        datetime: "2026-07-28T10:00:00",
        timezone: "Europe/Madrid",
        first_name: "Ana",
        last_name: "Lopez",
        email: "ana@example.com",
        utm_source: "newsletter",
        source_page: "https://example.com/b/agenda-test?utm_source=newsletter",
        referrer: "https://google.com"
      },
      request: request,
      client: client
    )

    expect(result.booking).to be_persisted
    expect(result.booking.meet_link).to eq("https://meet.google.com/abc")
    expect(result.booking.metadata).to include(
      "booking_page_slug" => "creator-test",
      "booking_page_name" => "Agenda",
      "utm_source" => "newsletter",
      "source_page" => "https://example.com/b/agenda-test?utm_source=newsletter",
      "referrer" => "https://google.com",
      "ip" => "127.0.0.1",
      "user_agent" => "rspec"
    )
    expect(workspace.people.with_email("ana@example.com")).to exist
    expect(workspace.deals.where("name ILIKE ?", "%Ana Lopez%")).to exist
    expect(client).to have_received(:create_event)
  end
end
