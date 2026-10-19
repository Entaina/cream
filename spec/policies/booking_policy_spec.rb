require "rails_helper"

RSpec.describe BookingPolicy do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:host) { users(:two) }
  let(:admin) { users(:one) }
  let(:booking_page) { create_booking_page!(host: host) }
  let(:booking) { create_booking!(booking_page) }

  def context_for(user)
    UserContext.new(user: user, workspace: workspace)
  end

  it "lets the host see and cancel the booking" do
    policy = described_class.new(context_for(host), booking)

    expect(policy.cancel?).to be true
    expect(described_class::Scope.new(context_for(host), Booking.all).resolve).to include(booking)
  end

  it "hides the booking from other members, including admins" do
    policy = described_class.new(context_for(admin), booking)

    expect(policy.cancel?).to be false
    expect(described_class::Scope.new(context_for(admin), Booking.all).resolve).not_to include(booking)
  end

  it "lets a co-host see and cancel the booking" do
    booking_page.members.create!(user: admin)
    policy = described_class.new(context_for(admin), booking)

    expect(policy.cancel?).to be true
    expect(described_class::Scope.new(context_for(admin), Booking.all).resolve).to include(booking)
  end

  it "hides the booking from members who are not co-hosts of its page" do
    booking_page.members.create!(user: users(:three))

    expect(described_class.new(context_for(admin), booking).cancel?).to be false
    expect(described_class::Scope.new(context_for(admin), Booking.all).resolve).not_to include(booking)
  end

  def create_booking_page!(host:)
    pipeline = Pipeline.default_for(workspace) || Pipeline.create_default!(workspace)
    page = workspace.booking_pages.new(
      name: "Agenda",
      slug: "policy-bookings-#{host.id}",
      host: host,
      pipeline: pipeline,
      timezone: "Europe/Madrid",
      calendar_ids: ["primary"]
    )
    page.event_types.build(
      BookingEventType.blank_attributes.merge(slug: "video", name_i18n: {"es" => "Video"})
    )
    page.save!
    page
  end

  def create_booking!(page)
    Booking.create!(
      workspace: workspace,
      booking_page: page,
      booking_event_type: page.event_types.find_by!(slug: "video"),
      first_name: "Ana",
      last_name: "Lopez",
      email: "ana@example.com",
      starts_at: Time.zone.parse("2026-08-10 10:00"),
      ends_at: Time.zone.parse("2026-08-10 10:30"),
      timezone: "Europe/Madrid"
    )
  end
end
