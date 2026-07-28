require "rails_helper"

RSpec.describe Settings::CustomFieldPolicy do
  fixtures :users, :workspaces, :memberships, :custom_fields

  let(:workspace) { workspaces(:one) }
  let(:admin) { users(:one) }
  let(:member) { users(:two) }
  let(:field) { custom_fields(:person_tier) }

  def context_for(user, ws)
    UserContext.new(user: user, workspace: ws)
  end

  describe "for an admin" do
    subject(:policy) { described_class.new(context_for(admin, workspace), field) }

    it "permits field management" do
      expect(policy.index?).to be true
      expect(policy.create?).to be true
      expect(policy.update?).to be true
      expect(policy.destroy?).to be true
    end
  end

  describe "for a member" do
    subject(:policy) { described_class.new(context_for(member, workspace), field) }

    it "allows listing but forbids management" do
      expect(policy.index?).to be true
      expect(policy.create?).to be false
      expect(policy.update?).to be false
      expect(policy.destroy?).to be false
    end
  end
end
