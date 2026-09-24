require "rails_helper"

RSpec.describe EmailSubscription, type: :model do
  fixtures :users, :workspaces, :memberships, :companies

  let(:workspace) { workspaces(:one) }
  let(:person) { create_person!(workspace, company: companies(:acme), email: "sub@example.com") }

  before { SubscriptionType.ensure_defaults!(workspace) }

  it "subscribes and unsubscribes" do
    type = workspace.subscription_types.find_by!(slug: "newsletter")
    subscription = workspace.email_subscriptions.create!(
      person: person,
      subscription_type: type,
      status: "pending"
    )

    subscription.subscribe!(source: "spec", legal_basis: "consent")
    expect(subscription.reload).to be_subscribed

    subscription.unsubscribe!(source: "spec")
    expect(subscription.reload.status).to eq("unsubscribed")
  end
end
