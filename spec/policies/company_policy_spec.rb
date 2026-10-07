require "rails_helper"

RSpec.describe CompanyPolicy do
  fixtures :users, :workspaces, :memberships, :companies

  let(:workspace) { workspaces(:one) }
  let(:member) { users(:one) }
  let(:outsider) { users(:outsider) }
  let(:company) { companies(:acme) }
  let(:other_company) { companies(:globex) }

  def context_for(user, ws)
    UserContext.new(user: user, workspace: ws)
  end

  describe "for a workspace member" do
    subject(:policy) { described_class.new(context_for(member, workspace), company) }

    it "permits CRUD actions" do
      expect(policy.index?).to be true
      expect(policy.show?).to be true
      expect(policy.create?).to be true
      expect(policy.update?).to be true
      expect(policy.destroy?).to be true
    end
  end

  describe "for an ai salesperson" do
    subject(:policy) { described_class.new(context_for(ai_user, workspace), company) }

    let(:ai_user) { users(:outsider) }

    before { Membership.create!(user: ai_user, workspace: workspace, role: "ai_salesperson") }

    it "can read and write but not destroy or merge" do
      expect(policy.show?).to be true
      expect(policy.create?).to be true
      expect(policy.update?).to be true
      expect(policy.destroy?).to be false
      expect(policy.merge?).to be false
    end
  end

  describe "for a non-member" do
    subject(:policy) { described_class.new(context_for(outsider, workspace), company) }

    it "forbids all actions" do
      expect(policy.index?).to be false
      expect(policy.show?).to be false
      expect(policy.create?).to be false
      expect(policy.update?).to be false
      expect(policy.destroy?).to be false
    end
  end

  describe "for a record in another workspace" do
    subject(:policy) { described_class.new(context_for(member, workspace), other_company) }

    it "forbids record actions" do
      expect(policy.show?).to be false
      expect(policy.update?).to be false
      expect(policy.destroy?).to be false
    end
  end

  describe "Scope" do
    it "returns workspace records for members" do
      scope = described_class::Scope.new(context_for(member, workspace), Company.all).resolve

      expect(scope).to contain_exactly(company)
    end

    it "returns nothing for non-members" do
      scope = described_class::Scope.new(context_for(outsider, workspace), Company.all).resolve

      expect(scope).to be_empty
    end
  end
end
