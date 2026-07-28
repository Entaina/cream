require "rails_helper"

RSpec.describe MembershipPolicy do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:admin) { users(:one) }
  let(:member) { users(:two) }
  let(:admin_membership) { memberships(:one_one) }
  let(:member_membership) { memberships(:one_member) }

  def context_for(user, ws)
    UserContext.new(user: user, workspace: ws)
  end

  describe "for an admin" do
    subject(:policy) { described_class.new(context_for(admin, workspace), member_membership) }

    it "permits updating another member" do
      expect(policy.update?).to be true
      expect(policy.destroy?).to be true
    end

    it "forbids updating own membership" do
      own_policy = described_class.new(context_for(admin, workspace), admin_membership)
      expect(own_policy.destroy?).to be false
    end
  end

  describe "for a member" do
    subject(:policy) { described_class.new(context_for(member, workspace), member_membership) }

    it "forbids management actions" do
      expect(policy.update?).to be false
      expect(policy.destroy?).to be false
    end
  end
end
