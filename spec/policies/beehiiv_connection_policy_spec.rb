require "rails_helper"

RSpec.describe BeehiivConnectionPolicy do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:admin) { users(:one) }
  let(:salesperson) { users(:two) }

  def context_for(user)
    UserContext.new(user: user, workspace: workspace)
  end

  let(:connection) { workspace.build_beehiiv_connection(api_key: "key", user: admin) }

  it "allows admin to create, update, destroy, and sync" do
    policy = described_class.new(context_for(admin), connection)
    expect(policy.create?).to be true
    connection.save!
    expect(described_class.new(context_for(admin), connection).update?).to be true
    expect(described_class.new(context_for(admin), connection).sync?).to be true
    expect(described_class.new(context_for(admin), connection).destroy?).to be true
  end

  it "forbids non-admin members" do
    policy = described_class.new(context_for(salesperson), connection)
    expect(policy.create?).to be false
    connection.save!
    expect(described_class.new(context_for(salesperson), connection).update?).to be false
    expect(described_class.new(context_for(salesperson), connection).sync?).to be false
  end
end
