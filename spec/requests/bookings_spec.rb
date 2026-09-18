require "rails_helper"

RSpec.describe "Bookings", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  fixtures :users, :workspaces, :memberships

  let(:user) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let(:pipeline) { Pipeline.default_for(workspace) || Pipeline.create_default!(workspace) }
  let(:booking_page) do
    page = workspace.booking_pages.new(
      name: "Agenda",
      slug: "bookings-index-test",
      host: user,
      pipeline: pipeline,
      timezone: "Europe/Madrid",
      calendar_ids: ["primary@gmail.com"]
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
  let(:event_type) { booking_page.event_types.find_by!(slug: "video") }
  let!(:booking) do
    Booking.create!(
      workspace: workspace,
      booking_page: booking_page,
      booking_event_type: event_type,
      first_name: "Ana",
      last_name: "Lopez",
      email: "ana@example.com",
      starts_at: Time.zone.parse("2026-08-10 10:00"),
      ends_at: Time.zone.parse("2026-08-10 10:30"),
      timezone: "Europe/Madrid",
      google_event_id: "evt1"
    )
  end
  let(:calendar_client) { instance_double(GoogleCalendar::Client, delete_event: nil) }

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:calendar_booking).and_return(true)
    sign_in_as(user)
    travel_to Time.zone.parse("2026-08-06 09:00")
  end

  describe "GET /bookings" do
    it "lists bookings for the workspace" do
      get bookings_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Ana Lopez")
      expect(response.body).to include("Online")
    end

    it "shows the booking time in the booking's timezone, not the viewer's" do
      user.update!(time_zone: "America/New_York")
      booking.update!(
        starts_at: Time.find_zone("UTC").local(2026, 8, 10, 8, 0),
        ends_at: Time.find_zone("UTC").local(2026, 8, 10, 8, 30)
      )

      get bookings_path

      expect(response.body).to include("10:00")
      expect(response.body).to include("Europe/Madrid")
      expect(response.body).not_to include("04:00")
    end
  end

  describe "PATCH /bookings/:id/cancel" do
    before do
      workspace.calendar_connections.create!(
        user: user,
        email: "host@example.com",
        refresh_token: "rt",
        access_token: "at",
        expires_at: 1.hour.from_now,
        granted_scopes: CalendarConnection::EVENTS_SCOPE
      )
      allow(GoogleCalendar::Client).to receive(:new).and_return(calendar_client)
    end

    it "cancels the booking and deletes the Google event" do
      patch cancel_booking_path(booking)

      expect(response).to redirect_to(bookings_path)
      expect(flash[:notice]).to eq(I18n.t("flashes.bookings.cancelled"))
      expect(booking.reload.status).to eq("cancelled")
      expect(calendar_client).to have_received(:delete_event).with(
        calendar_id: "primary@gmail.com",
        event_id: "evt1"
      )
    end

    it "shows an alert when Google fails" do
      allow(calendar_client).to receive(:delete_event).and_raise(GoogleCalendar::Error, "Google error")

      patch cancel_booking_path(booking)

      expect(response).to redirect_to(bookings_path)
      expect(flash[:alert]).to eq("Google error")
      expect(booking.reload.status).to eq("confirmed")
    end
  end
end
