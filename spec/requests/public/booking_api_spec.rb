require "rails_helper"

RSpec.describe Public::BookingApiController, type: :request do
  fixtures :users, :workspaces, :memberships
  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let!(:connection) do
    workspace.calendar_connections.create!(
      user: user,
      email: "host@example.com",
      refresh_token: "rt",
      access_token: "at",
      expires_at: 1.hour.from_now,
      granted_scopes: "#{CalendarConnection::READONLY_SCOPE} #{CalendarConnection::EVENTS_SCOPE}"
    )
  end
  let(:pipeline) { Pipeline.default_for(workspace) || Pipeline.create_default!(workspace) }
  let!(:booking_page) do
    page = workspace.booking_pages.new(
      name: "Agenda",
      slug: "agenda-test",
      host: user,
      pipeline: pipeline,
      welcome_message: "Bienvenido",
      timezone: "Europe/Madrid",
      calendar_ids: [ "primary" ]
    )
    page.event_types.build(
      slug: "video",
      name_i18n: { "es" => "Reunión On-line", "en" => "Online meeting" },
      description_i18n: { "es" => "Meet", "en" => "Meet" },
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
  let!(:event_type) { booking_page.event_types.find_by!(slug: "video") }
  let(:calendar_client) { instance_double(GoogleCalendar::Client) }

  def valid_booking_params(overrides = {})
    {
      event_type: "video",
      datetime: "2026-07-28T10:00:00",
      timezone: "Europe/Madrid",
      first_name: "Ana",
      last_name: "Lopez",
      email: "ana@example.com",
      BookingPage::TIMESTAMP_FIELD => BookingPage.signed_timestamp(at: 10.seconds.ago)
    }.merge(overrides)
  end

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:calendar_booking).and_return(true)
    allow(GoogleCalendar::Client).to receive(:new).and_return(calendar_client)
  end

  describe "GET /b/:slug/api/event-types" do
    it "returns visible event types and profile" do
      get public_booking_api_event_types_path(booking_page.slug, lang: "es")

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["profile"]["name"]).to eq(user.name)
      expect(body["event_types"].size).to eq(1)
      expect(body["event_types"].first["slug"]).to eq("video")
      expect(response.headers["Cache-Control"]).to include("max-age=300")
    end
  end

  describe "GET /b/:slug/api/availability" do
    it "returns monthly availability" do
      allow(BookingAvailabilityService).to receive(:monthly).and_return(
        BookingAvailabilityService::Result.new(
          days: [ { date: "2026-07-28", available: true } ],
          slots: nil,
          warning: nil
        )
      )

      get public_booking_api_availability_path(booking_page.slug),
        params: { event_type: "video", month: "2026-07", timezone: "Europe/Madrid" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["days"]).to eq([ { "date" => "2026-07-28", "available" => true } ])
    end

    it "returns daily slots" do
      allow(BookingAvailabilityService).to receive(:daily).and_return(
        BookingAvailabilityService::Result.new(days: nil, slots: [ "10:00", "10:15" ], warning: nil)
      )

      get public_booking_api_availability_path(booking_page.slug),
        params: { event_type: "video", date: "2026-07-28", timezone: "Europe/Madrid" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["slots"]).to eq([ "10:00", "10:15" ])
    end
  end

  describe "POST /b/:slug/api/book" do
    let(:booking) do
      Booking.new(
        id: 1,
        first_name: "Ana",
        last_name: "Lopez",
        email: "ana@example.com",
        starts_at: Time.zone.parse("2026-07-28 10:00"),
        ends_at: Time.zone.parse("2026-07-28 10:30"),
        timezone: "Europe/Madrid",
        guest_emails: [],
        booking_page: booking_page,
        booking_event_type: event_type,
        workspace: workspace
      )
    end

    it "creates a booking" do
      allow(BookingCreator).to receive(:call).and_return(BookingCreator::Result.new(booking: booking))

      post public_booking_api_book_path(booking_page.slug),
        params: valid_booking_params,
        as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["attendee_email"]).to eq("ana@example.com")
      expect(BookingCreator).to have_received(:call)
    end

    it "silently accepts honeypot submissions" do
      expect(BookingCreator).not_to receive(:call)

      expect {
        post public_booking_api_book_path(booking_page.slug),
          params: valid_booking_params(email: "bot@example.com", BookingPage::HONEYPOT_FIELD => "spam"),
          as: :json
      }.not_to change(Booking, :count)

      expect(response).to have_http_status(:created)
    end

    it "silently discards submissions faster than the time-trap" do
      expect(BookingCreator).not_to receive(:call)

      expect {
        post public_booking_api_book_path(booking_page.slug),
          params: valid_booking_params(BookingPage::TIMESTAMP_FIELD => BookingPage.signed_timestamp),
          as: :json
      }.not_to change(Booking, :count)

      expect(response).to have_http_status(:created)
    end

    it "silently discards submissions without a valid time-trap token" do
      expect(BookingCreator).not_to receive(:call)

      expect {
        post public_booking_api_book_path(booking_page.slug),
          params: valid_booking_params(BookingPage::TIMESTAMP_FIELD => "forged"),
          as: :json
      }.not_to change(Booking, :count)

      expect(response).to have_http_status(:created)
    end

    it "silently discards submissions when the page hourly cap is exceeded" do
      stub_const("BookingPage::MAX_BOOKINGS_PER_PAGE_PER_HOUR", 1)
      booking_page.bookings.create!(
        workspace: workspace,
        booking_event_type: event_type,
        first_name: "Prev",
        last_name: "Guest",
        email: "prev@example.com",
        starts_at: 1.day.from_now,
        ends_at: 1.day.from_now + 30.minutes,
        timezone: "Europe/Madrid"
      )

      expect(BookingCreator).not_to receive(:call)

      expect {
        post public_booking_api_book_path(booking_page.slug),
          params: valid_booking_params(email: "new@example.com"),
          as: :json
      }.not_to change(Booking, :count)

      expect(response).to have_http_status(:created)
    end

    it "silently discards submissions when the email daily cap is exceeded" do
      stub_const("BookingPage::MAX_BOOKINGS_PER_EMAIL_PER_DAY", 1)
      booking_page.bookings.create!(
        workspace: workspace,
        booking_event_type: event_type,
        first_name: "Prev",
        last_name: "Guest",
        email: "ana@example.com",
        starts_at: 1.day.from_now,
        ends_at: 1.day.from_now + 30.minutes,
        timezone: "Europe/Madrid"
      )

      expect(BookingCreator).not_to receive(:call)

      expect {
        post public_booking_api_book_path(booking_page.slug),
          params: valid_booking_params,
          as: :json
      }.not_to change(Booking, :count)

      expect(response).to have_http_status(:created)
    end

    it "returns conflict when slot is taken" do
      allow(BookingCreator).to receive(:call).and_raise(BookingCreator::Conflict, "occupied")

      post public_booking_api_book_path(booking_page.slug),
        params: valid_booking_params,
        as: :json

      expect(response).to have_http_status(:conflict)
    end
  end
end
