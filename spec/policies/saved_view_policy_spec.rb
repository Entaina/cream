require "rails_helper"

RSpec.describe SavedViewPolicy do
  fixtures :users, :workspaces, :memberships, :saved_views

  let(:workspace) { workspaces(:one) }
  let(:admin) { users(:one) }
  let(:member) { users(:two) }
  let(:personal_view) { saved_views(:person_gold) }
  let(:shared_view) { saved_views(:person_shared) }
  let(:member_view) { saved_views(:member_private) }

  def context_for(user, ws)
    UserContext.new(user: user, workspace: ws)
  end

  describe "scope" do
    it "returns visible views for the current user" do
      scope = described_class::Scope.new(context_for(member, workspace), SavedView.all).resolve

      expect(scope).to include(shared_view, member_view)
      expect(scope).not_to include(personal_view, saved_views(:other_workspace))
    end
  end

  describe "for an admin" do
    it "allows creating views" do
      policy = described_class.new(context_for(admin, workspace), SavedView.new)

      expect(policy.create?).to be true
    end

    it "allows updating own personal views" do
      policy = described_class.new(context_for(admin, workspace), personal_view)

      expect(policy.update?).to be true
      expect(policy.destroy?).to be true
    end

    it "allows updating shared views" do
      policy = described_class.new(context_for(admin, workspace), shared_view)

      expect(policy.update?).to be true
      expect(policy.destroy?).to be true
    end
  end

  describe "for a member" do
    it "allows creating views" do
      policy = described_class.new(context_for(member, workspace), SavedView.new)

      expect(policy.create?).to be true
    end

    it "forbids updating another user's personal view" do
      policy = described_class.new(context_for(member, workspace), personal_view)

      expect(policy.update?).to be false
      expect(policy.destroy?).to be false
    end

    it "allows updating own personal views" do
      policy = described_class.new(context_for(member, workspace), member_view)

      expect(policy.update?).to be true
      expect(policy.destroy?).to be true
    end

    it "forbids updating shared views owned by someone else" do
      policy = described_class.new(context_for(member, workspace), shared_view)

      expect(policy.update?).to be false
      expect(policy.destroy?).to be false
    end
  end
end
