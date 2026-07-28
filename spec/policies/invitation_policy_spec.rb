require "rails_helper"

RSpec.describe InvitationPolicy do
  fixtures :users, :workspaces, :memberships, :invitations

  let(:workspace) { workspaces(:one) }
  let(:admin) { users(:one) }
  let(:member) { users(:two) }
  let(:invitation) { invitations(:pending) }

  def context_for(user, ws)
    UserContext.new(user: user, workspace: ws)
  end

  describe "for an admin" do
    subject(:policy) { described_class.new(context_for(admin, workspace), invitation) }

    it "permits invitation management" do
      expect(policy.create?).to be true
      expect(policy.destroy?).to be true
      expect(policy.resend?).to be true
    end
  end

  describe "for a member" do
    subject(:policy) { described_class.new(context_for(member, workspace), invitation) }

    it "forbids invitation management" do
      expect(policy.create?).to be false
      expect(policy.destroy?).to be false
      expect(policy.resend?).to be false
    end
  end
end
