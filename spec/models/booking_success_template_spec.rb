require "rails_helper"

RSpec.describe BookingSuccessTemplateAssignable, type: :model do
  fixtures :users, :workspaces, :memberships
  let(:workspace) { workspaces(:one) }
  let(:other_workspace) { workspaces(:two) }
  let(:user) { users(:one) }
  let(:pipeline) { Pipeline.default_for(workspace) || Pipeline.create_default!(workspace) }

  def build_booking_page
    page = workspace.booking_pages.new(
      name: "Agenda",
      slug: "agenda-#{SecureRandom.hex(3)}",
      host: user,
      pipeline: pipeline,
      timezone: "Europe/Madrid",
      calendar_ids: ["primary"]
    )
    page.event_types.build(
      slug: "call",
      name_i18n: {"es" => "Llamada"},
      duration_minutes: 30,
      location_type: "google_meet",
      weekly_hours: BookingEventType::DEFAULT_WEEKLY_HOURS,
      slot_increment_minutes: 15,
      min_notice_hours: 0,
      visible: true
    )
    page
  end

  def booking_template(for_workspace: workspace, slug: "acuse")
    for_workspace.lead_form_templates.create!(
      kind: "booking",
      partial: false,
      slug: slug,
      body: "<p>Gracias</p>"
    )
  end

  it "accepts a booking acknowledgment template on the page" do
    page = build_booking_page
    page.success_template = booking_template

    expect(page).to be_valid
  end

  it "rejects a lead form template" do
    page = build_booking_page
    page.success_template = workspace.lead_form_templates.create!(
      kind: "form",
      partial: false,
      slug: "contacto-test",
      body: "{% form_open %}{% form_close %}"
    )

    expect(page).not_to be_valid
    expect(page.errors[:success_template]).to be_present
  end

  it "rejects a template from another workspace" do
    page = build_booking_page
    page.success_template = booking_template(for_workspace: other_workspace, slug: "other")

    expect(page).not_to be_valid
  end
end
