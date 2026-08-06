require "rails_helper"

RSpec.describe BookingCanceller, type: :service do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let(:pipeline) { Pipeline.default_for(workspace) || Pipeline.create_default!(workspace) }
  let(:booking_page) do
    page = workspace.booking_pages.new(
      name: "Agenda",
      slug: "cancel-test",
      host: user,
      pipeline: pipeline,
      timezone: "Europe/Madrid",
      calendar_ids: [ "primary@gmail.com" ]
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
  let(:booking) do
    Booking.create!(
      workspace: workspace,
      booking_page: booking_page,
      booking_event_type: event_type,
      first_name: "Ana",
      last_name: "Lopez",
      email: "ana@example.com",
      starts_at: 1.day.from_now,
      ends_at: 1.day.from_now + 30.minutes,
      timezone: "Europe/Madrid",
      google_event_id: "evt1"
    )
  end

  before do
    allow(client).to receive(:delete_event)
  end

  it "marks the booking as cancelled and deletes the Google event" do
    result = described_class.call(booking:, client:)

    expect(result.booking.status).to eq("cancelled")
    expect(client).to have_received(:delete_event).with(
      calendar_id: "primary@gmail.com",
      event_id: "evt1"
    )
  end

  it "marks the booking as cancelled when there is no Google event id" do
    booking.update!(google_event_id: nil)

    result = described_class.call(booking:, client:)

    expect(result.booking.status).to eq("cancelled")
    expect(client).not_to have_received(:delete_event)
  end

  it "does not mark the booking as cancelled when Google fails" do
    allow(client).to receive(:delete_event).and_raise(GoogleCalendar::Error, "API error")

    expect {
      described_class.call(booking:, client:)
    }.to raise_error(GoogleCalendar::Error, "API error")

    expect(booking.reload.status).to eq("confirmed")
  end

  it "is a no-op when the booking is already cancelled" do
    booking.update!(status: "cancelled")

    result = described_class.call(booking:, client:)

    expect(result.booking.status).to eq("cancelled")
    expect(client).not_to have_received(:delete_event)
  end
end
