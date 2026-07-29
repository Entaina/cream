require "rails_helper"

RSpec.describe AlertRuleEngine, type: :service do
  fixtures :users, :workspaces, :memberships, :companies

  let(:workspace) { workspaces(:one) }
  let(:owner) { users(:one) }
  let(:pipeline) { Pipeline.create_default!(workspace) }
  let(:company) { companies(:acme) }
  let(:product) { workspace.products.create!(name: "Plan", price: 100) }
  let!(:rule) do
    workspace.alert_rules.create!(
      name: "Edición finalizada sin datos fiscales",
      trigger_field: "edition_ends_on",
      offset_days: 0,
      conditions: %w[company_without_fiscal_info],
      recipient: "deal_owner"
    )
  end

  before do
    company.update!(fiscal_information: nil)
    memberships(:one_one).update!(alert_in_app: true, alert_email: false)
  end

  def create_matching_deal
    deal = create_deal!(workspace, pipeline: pipeline, company: company, owner: owner)
    edition = workspace.editions.create!(name: "Madrid 2026", ends_on: Date.current - 1)
    deal.deal_products.create!(product: product, quantity: 1, edition: edition)
    deal
  end

  it "notifies the deal owner when edition ended and company lacks fiscal info" do
    deal = create_matching_deal

    expect {
      described_class.run!(workspace)
    }.to change { owner.notifications.where(kind: "alert").count }.by(1)

    notification = owner.notifications.order(:id).last
    expect(notification.title).to eq(rule.name)
    expect(notification.body).to include(deal.name)
    expect(rule.alert_deliveries.find_by(deal: deal, user: owner)).to be_present
  end

  it "does not notify twice for the same deal and recipient" do
    create_matching_deal

    described_class.run!(workspace)
    expect {
      described_class.run!(workspace)
    }.not_to change { owner.notifications.where(kind: "alert").count }
  end

  it "skips delivery when the recipient disabled all channels" do
    memberships(:one_one).update!(alert_in_app: false, alert_email: false)
    create_matching_deal

    expect {
      described_class.run!(workspace)
    }.not_to change(AlertDelivery, :count)
  end

  it "delivers email when the recipient enabled that channel" do
    memberships(:one_one).update!(alert_in_app: false, alert_email: true)
    create_matching_deal

    expect {
      described_class.run!(workspace)
    }.to have_enqueued_mail(AlertMailer, :alert_email).with(
      hash_including(user: owner, rule: rule)
    )
  end

  it "does not match when the company has fiscal information" do
    company.update!(fiscal_information: "B12345678")
    create_matching_deal

    expect {
      described_class.run!(workspace)
    }.not_to change(AlertDelivery, :count)
  end

  it "notifies workspace admins when configured" do
    rule.update!(recipient: "admins")
    create_matching_deal

    expect {
      described_class.run!(workspace)
    }.to change { owner.notifications.where(kind: "alert").count }.by(1)
  end
end
