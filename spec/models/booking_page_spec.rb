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

  describe "crm_association" do
    def page_with_event_type(**attrs)
      page = build_page(**attrs)
      page.event_types.build(BookingEventType.blank_attributes.merge(slug: "call", name_i18n: {"es" => "Llamada"}))
      page
    end

    it "defaults to deal and requires a pipeline" do
      page = page_with_event_type(pipeline: nil)

      expect(page.crm_association).to eq("deal")
      expect(page).not_to be_valid
      expect(page.errors[:pipeline]).to be_present
    end

    it "does not require a pipeline for person and none" do
      expect(page_with_event_type(crm_association: "person", pipeline: nil)).to be_valid
      expect(page_with_event_type(crm_association: "none", pipeline: nil)).to be_valid
    end

    it "rejects unknown values" do
      expect(page_with_event_type(crm_association: "company")).not_to be_valid
    end
  end
end
