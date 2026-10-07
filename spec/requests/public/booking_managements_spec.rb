require "rails_helper"

RSpec.describe "Public booking management", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let(:pipeline) { Pipeline.default_for(workspace) || Pipeline.create_default!(workspace) }
  let!(:booking_page) do
    page = workspace.booking_pages.new(
      name: "Agenda",
      slug: "manage-test",
      host: user,
      pipeline: pipeline,
      timezone: "Europe/Madrid",
      calendar_ids: ["primary"],
      active: true
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
  let!(:booking) do
    Booking.create!(
      workspace: workspace,
      booking_page: booking_page,
      booking_event_type: event_type,
      first_name: "Ana",
      last_name: "Lopez",
      email: "ana@example.com",
      starts_at: 2.days.from_now,
      ends_at: 2.days.from_now + 30.minutes,
      timezone: "Europe/Madrid",
      google_event_id: "evt123"
    )
  end
  let(:token) { booking.manage_token }
  let(:calendar_client) { instance_double(GoogleCalendar::Client, delete_event: true) }

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:calendar_booking).and_return(true)
    workspace.calendar_connections.create!(
      user: user,
      email: "host@example.com",
      refresh_token: "rt",
      access_token: "at",
      expires_at: 1.hour.from_now,
      granted_scopes: "#{CalendarConnection::READONLY_SCOPE} #{CalendarConnection::EVENTS_SCOPE}"
    )
    allow(GoogleCalendar::Client).to receive(:new).and_return(calendar_client)
  end

  describe "GET cancel" do
    it "shows the cancel confirmation page" do
      get public_booking_cancel_path(booking_page.slug, token)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("booking.manage.cancel_title"))
    end

    it "returns not found for an invalid token" do
      get public_booking_cancel_path(booking_page.slug, "invalid")

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST cancel" do
    it "cancels the booking and deletes the google event when connected" do
      expect(calendar_client).to receive(:delete_event).with(calendar_id: "primary", event_id: "evt123")

      post public_booking_cancel_path(booking_page.slug, token)

      expect(response).to have_http_status(:ok)
      expect(booking.reload.status).to eq("cancelled")
      expect(response.body).to include(I18n.t("booking.manage.cancelled_title"))
    end
  end

  describe "GET reschedule" do
    it "renders the booking widget in reschedule mode" do
      get public_booking_reschedule_path(booking_page.slug, token)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('data-booking-reschedule-mode-value="true"')
      expect(response.body).to include("data-booking-reschedule-token-value")
    end
  end
end
