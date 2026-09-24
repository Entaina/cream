require "rails_helper"

RSpec.describe BookingPage, type: :model do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:host) { users(:one) }
  let(:pipeline) { Pipeline.create_default!(workspace) }

  def build_page(**attrs)
    workspace.booking_pages.new({
      name: "Agenda",
      slug: "agenda-test",
      host: host,
      pipeline: pipeline,
      timezone: "Europe/Madrid",
      calendar_ids: ["primary"]
    }.merge(attrs))
  end

  it "requires a slug and event types" do
    page = build_page
    page.event_types.build(BookingEventType.blank_attributes.merge(slug: "call", name_i18n: {"es" => "Llamada"}))

    expect(page).to be_valid
    expect(page.slug).to eq("agenda-test")
  end

  it "is not ready when inactive" do
    page = build_page(active: false)
    page.event_types.build(BookingEventType.blank_attributes.merge(slug: "call", name_i18n: {"es" => "Llamada"}))
    page.save!

    expect(page.ready_for_booking?).to be false
  end
end
