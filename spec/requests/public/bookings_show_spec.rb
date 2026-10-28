require "rails_helper"

RSpec.describe "Public booking page", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let(:pipeline) { Pipeline.default_for(workspace) || Pipeline.create_default!(workspace) }
  let!(:booking_page) do
    page = workspace.booking_pages.new(
      name: "Agenda",
      slug: "agenda-show",
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

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:calendar_booking).and_return(true)
  end

  it "renders the booking page shell with progress and i18n targets" do
    get public_booking_page_path(booking_page.slug, lang: "es")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('class="public-booking-shell"')
    expect(response.body).to include('data-booking-target="progress"')
    expect(response.body).to include('data-booking-target="progressEventLabel"')
    expect(response.body).to include('data-booking-target="localeEs"')
    expect(response.body).to include('data-booking-target="honeypotLabel"')
    expect(response.body).to include('lang="es"')
    expect(response.body).to include("data-booking-copy-value=")
    expect(response.body).to include(I18n.t("booking.public_ui.chooseEvent", locale: :es))
  end

  it "renders the Turnstile widget when Turnstile is enabled" do
    allow(TurnstileVerifier).to receive_messages(enabled?: true, site_key: "site-key-123")

    get public_booking_page_path(booking_page.slug)

    expect(response.body).to include('data-sitekey="site-key-123"')
    expect(response.body).to include('data-booking-target="turnstile"')
    expect(response.body).to include("https://challenges.cloudflare.com/turnstile/v0/api.js")
  end

  it "does not render the Turnstile widget when Turnstile is disabled" do
    allow(TurnstileVerifier).to receive(:enabled?).and_return(false)

    get public_booking_page_path(booking_page.slug)

    expect(response.body).not_to include("cf-turnstile")
  end

  it "renders English aria labels when lang=en" do
    get public_booking_page_path(booking_page.slug, lang: "en")

    expect(response.body).to include(I18n.t("booking.public_ui.aria.language", locale: :en))
    expect(response.body).to include(I18n.t("booking.public_ui.chooseEvent", locale: :en))
  end

  it "renders prefill and confirmation targets" do
    get public_booking_page_path(
      booking_page.slug,
      first_name: "Ana",
      last_name: "Lopez",
      email: "ana@example.com",
      hide_known: "true"
    )

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('data-booking-target="confirmPanel"')
    expect(response.body).to include('data-booking-target="firstNameField"')
    expect(response.body).to include('name="first_name"')
    expect(response.body).to include('name="last_name"')
    expect(response.body).to include('name="email"')
  end

  it "renders a direct event type link on the calendar step" do
    get public_booking_event_type_path(booking_page.slug, "video", lang: "es")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('data-booking-event-type-value="video"')
    expect(response.body).to include('data-booking-target="stepEventTypes" class="public-booking-step hidden"')
    expect(response.body).to include('data-booking-target="stepSchedule" class="public-booking-step"')
    expect(response.body).to include('data-booking-target="progressEvent" class="public-booking-progress-step hidden"')
    expect(response.body).to include('data-booking-target="progressEventSeparator" class="public-booking-progress-separator hidden"')
    expect(response.body).to include('data-booking-target="backToTypesWrap" class="hidden"')
    expect(response.body).to include('data-action="click->booking#goToFirstStep keydown->booking#profileKeydown"')
    expect(response.body).to include('data-action="booking#goToStep" data-step="eventTypes" disabled')
    expect(response.body).to include('data-action="booking#goToStep" data-step="schedule" disabled')
    expect(response.body).to include('data-booking-target="progressSchedule" class="public-booking-progress-step is-active"')
    expect(response.body).to include('<span class="public-booking-progress-number">1</span>')
    expect(response.body).to include('<span class="public-booking-progress-number">2</span>')
    expect(response.body).not_to include('<span class="public-booking-progress-number">3</span>')
  end

  it "returns not found for unknown event type" do
    get public_booking_event_type_path(booking_page.slug, "missing")

    expect(response).to have_http_status(:not_found)
  end

  it "returns not found for hidden event type" do
    booking_page.event_types.find_by!(slug: "video").update!(visible: false)

    get public_booking_event_type_path(booking_page.slug, "video")

    expect(response).to have_http_status(:not_found)
  end

  it "wraps the booking widget in the workspace public layout template" do
    layout = workspace.lead_form_templates.create!(
      kind: "layout",
      path: "public/layouts/agenda_wrap",
      partial: false,
      body: '<div data-test="public-layout-header">Header</div>{{ content }}'
    )
    workspace.update!(public_layout_template: layout)

    get public_booking_page_path(booking_page.slug, lang: "es")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('data-test="public-layout-header"')
    expect(response.body).to include('class="public-booking-shell"')
  end
end
