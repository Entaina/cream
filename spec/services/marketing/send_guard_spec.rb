require "rails_helper"

RSpec.describe Marketing::SendGuard do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:person) { create_person!(workspace, email: "allowed@example.com") }
  let(:newsletter_type) do
    SubscriptionType.ensure_defaults!(workspace)
    workspace.subscription_types.find_by!(slug: "newsletter")
  end

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:marketing_consent).and_return(true)
  end

  it "blocks suppressed addresses" do
    EmailSuppression.suppress!(workspace: workspace, address: person.email, reason: "manual")

    expect(described_class.allowed?(workspace: workspace, address: person.email, subscription_type: newsletter_type)).to be(false)
  end

  it "allows subscribed addresses" do
    Marketing::ConsentService.subscribe!(
      person: person,
      subscription_type: newsletter_type,
      source: "test",
      legal_basis: "consent"
    )

    expect(described_class.allowed?(workspace: workspace, address: person.email, subscription_type: newsletter_type)).to be(true)
  end

  it "filters a list of addresses" do
    Marketing::ConsentService.subscribe!(
      person: person,
      subscription_type: newsletter_type,
      source: "test",
      legal_basis: "consent"
    )

    filtered = described_class.filter_addresses(
      workspace: workspace,
      addresses: [ person.email, "blocked@example.com" ],
      subscription_type: newsletter_type
    )

    expect(filtered).to eq([ person.email ])
  end
end
