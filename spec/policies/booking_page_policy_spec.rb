require "rails_helper"

RSpec.describe BookingPagePolicy do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:host) { users(:two) }
  let(:admin) { users(:one) }
  let(:page) { workspace.booking_pages.new(host: host) }

  def context_for(user)
    UserContext.new(user: user, workspace: workspace)
  end

  it "lets any member list pages" do
    expect(described_class.new(context_for(admin), BookingPage).index?).to be true
  end

  it "lets the host edit and delete the page" do
    policy = described_class.new(context_for(host), page)

    expect(policy.update?).to be true
    expect(policy.edit?).to be true
    expect(policy.destroy?).to be true
  end

  it "forbids another member, including an admin, from editing the page" do
    policy = described_class.new(context_for(admin), page)

    expect(policy.update?).to be false
    expect(policy.destroy?).to be false
  end

  it "scopes the listing to every page in the workspace" do
    saved = create_booking_page!(host: host)

    expect(described_class::Scope.new(context_for(admin), BookingPage.all).resolve).to include(saved)
  end

  it "lets a co-host edit and delete the page" do
    saved = create_booking_page!(host: host)
    saved.members.create!(user: admin)
    policy = described_class.new(context_for(admin), saved)

    expect(policy.update?).to be true
    expect(policy.destroy?).to be true
  end

  it "forbids a member who is neither host nor co-host" do
    saved = create_booking_page!(host: host)
    saved.members.create!(user: users(:three))

    expect(described_class.new(context_for(admin), saved).update?).to be false
  end

  def create_booking_page!(host:)
    pipeline = Pipeline.default_for(workspace) || Pipeline.create_default!(workspace)
    page = workspace.booking_pages.new(
      name: "Agenda",
      slug: "policy-page-#{host.id}",
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
end
