require "rails_helper"

RSpec.describe ApiTokenPolicy do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:member) { users(:one) }
  let(:other_user) { users(:two) }
  let(:outsider) { users(:outsider) }
  let(:own_token) { member.api_tokens.create!(name: "Mine", workspace: workspace) }
  let(:other_token) { other_user.api_tokens.create!(name: "Theirs", workspace: workspaces(:two)) }

  def context_for(user, ws)
    UserContext.new(user: user, workspace: ws)
  end

  describe "for a workspace member" do
    subject(:policy) { described_class.new(context_for(member, workspace), own_token) }

    it "permits token management" do
      expect(policy.index?).to be true
      expect(policy.create?).to be true
      expect(policy.destroy?).to be true
    end
  end

  describe "for another users token" do
    subject(:policy) { described_class.new(context_for(member, workspace), other_token) }

    it "forbids destroy" do
      expect(policy.destroy?).to be false
    end
  end

  describe "for a non-member" do
    subject(:policy) { described_class.new(context_for(outsider, workspace), own_token) }

    it "forbids all actions" do
      expect(policy.index?).to be false
      expect(policy.create?).to be false
      expect(policy.destroy?).to be false
    end
  end

  describe "Scope" do
    it "returns only the users tokens in the workspace" do
      own_token
      other_token

      scope = described_class::Scope.new(context_for(member, workspace), ApiToken.all).resolve

      expect(scope).to contain_exactly(own_token)
    end

    it "returns nothing for non-members" do
      scope = described_class::Scope.new(context_for(outsider, workspace), ApiToken.all).resolve

      expect(scope).to be_empty
    end
  end
end
