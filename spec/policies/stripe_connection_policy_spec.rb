require "rails_helper"

RSpec.describe StripeConnectionPolicy do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:admin) { users(:one) }
  let(:salesperson) { users(:two) }

  def context_for(user)
    UserContext.new(user: user, workspace: workspace)
  end

  let(:connection) do
    workspace.stripe_connections.create!(user: admin, api_key: "sk_test_abc1234567890")
  end

  it "allows admin to manage and sync" do
    policy = described_class.new(context_for(admin), connection)
    expect(policy.update?).to be true
    expect(policy.sync?).to be true
    expect(policy.destroy?).to be true
  end

  it "forbids non-admin members" do
    policy = described_class.new(context_for(salesperson), connection)
    expect(policy.update?).to be false
    expect(policy.sync?).to be false
    expect(policy.destroy?).to be false
  end
end
