require "rails_helper"

RSpec.describe GmailConnectionPolicy do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:owner) { users(:one) }
  let(:other_member) { users(:two) }

  def context_for(user)
    UserContext.new(user: user, workspace: workspace)
  end

  let(:connection) do
    workspace.gmail_connections.create!(user: owner, refresh_token: "rt")
  end

  it "allows the owner to manage their connection" do
    policy = described_class.new(context_for(owner), connection)
    expect(policy.create?).to be true
    expect(policy.update?).to be true
    expect(policy.sync?).to be true
    expect(policy.destroy?).to be true
  end

  it "forbids another member from updating someone else's connection" do
    policy = described_class.new(context_for(other_member), connection)
    expect(policy.update?).to be false
    expect(policy.destroy?).to be false
  end

  it "forbids creating a connection for another user" do
    foreign = workspace.gmail_connections.build(user: owner)
    policy = described_class.new(context_for(other_member), foreign)
    expect(policy.create?).to be false
  end
end
