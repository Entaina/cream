require "rails_helper"

RSpec.describe Marketing::MqlEligibility do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:person) { create_person!(workspace, email: "mql@example.com") }

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:marketing_consent).and_return(true)
    SubscriptionType.ensure_defaults!(workspace)
  end

  it "includes subscribed persons with primary email and no suppression" do
    type = workspace.subscription_types.find_by!(slug: "general")
    Marketing::ConsentService.subscribe!(
      person: person,
      subscription_type: type,
      source: "spec",
      legal_basis: "consent"
    )

    expect(described_class.eligible?(person)).to be(true)
    expect(described_class.scope(workspace: workspace)).to contain_exactly(person)
  end

  it "excludes suppressed addresses" do
    type = workspace.subscription_types.find_by!(slug: "general")
    Marketing::ConsentService.subscribe!(person: person, subscription_type: type, source: "spec", legal_basis: "consent")
    EmailSuppression.suppress!(workspace: workspace, address: person.email, reason: "unsubscribe")

    expect(described_class.eligible?(person)).to be(false)
  end
end
