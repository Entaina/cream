require "rails_helper"

RSpec.describe "Public booking received page", type: :request do
  fixtures :users, :workspaces, :memberships
  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let(:pipeline) { Pipeline.default_for(workspace) || Pipeline.create_default!(workspace) }
  let!(:booking_page) do
    page = workspace.booking_pages.new(
      name: "Agenda",
      slug: "agenda-test",
      host: user,
      pipeline: pipeline,
      timezone: "Europe/Madrid",
      calendar_ids: ["primary"]
    )
    page.event_types.build(
      slug: "video",
      name_i18n: {"es" => "Reunión"},
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
  let!(:success_template) do
    workspace.lead_form_templates.create!(
      kind: "booking",
      partial: false,
      slug: "acuse",
      body: <<~LIQUID
        <div class="acuse">
          <p>Evento: {{ evento }}</p>
          {% partial 'google_analytics' %}
        </div>
      LIQUID
    )
  end

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:calendar_booking).and_return(true)
    workspace.lead_form_templates.find_or_create_by!(path: "public/lead_forms/partials/google_analytics") do |t|
      t.partial = true
      t.kind = "form"
      t.body = "{% google_analytics %}"
    end
  end

  it "renders the resolved template with evento assign" do
    booking_page.update!(success_template: success_template)

    get public_booking_received_path(booking_page.slug, evento: event_type.slug)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Evento: video")
  end

  it "returns not found without a configured template" do
    get public_booking_received_path(booking_page.slug, evento: event_type.slug)

    expect(response).to have_http_status(:not_found)
  end

  it "returns not found for unknown event types" do
    booking_page.update!(success_template: success_template)

    get public_booking_received_path(booking_page.slug, evento: "missing")

    expect(response).to have_http_status(:not_found)
  end
end
