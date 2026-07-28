require "rails_helper"

RSpec.describe WorkspacePolicy do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:member) { users(:one) }
  let(:outsider) { users(:outsider) }

  def context_for(user, ws)
    UserContext.new(user: user, workspace: ws)
  end

  describe "for a workspace member" do
    subject(:policy) { described_class.new(context_for(member, workspace), workspace) }

    it "permits workspace actions" do
      expect(policy.show?).to be true
      expect(policy.search?).to be true
      expect(policy.dashboard?).to be true
    end
  end

  describe "for a non-member" do
    subject(:policy) { described_class.new(context_for(outsider, workspace), workspace) }

    it "forbids workspace actions" do
      expect(policy.show?).to be false
      expect(policy.search?).to be false
      expect(policy.dashboard?).to be false
    end
  end

  describe "Scope" do
    it "returns the current workspace for members" do
      scope = described_class::Scope.new(context_for(member, workspace), Workspace.all).resolve

      expect(scope).to contain_exactly(workspace)
    end

    it "returns nothing for non-members" do
      scope = described_class::Scope.new(context_for(outsider, workspace), Workspace.all).resolve

      expect(scope).to be_empty
    end
  end
end
