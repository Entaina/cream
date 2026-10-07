require "rails_helper"

RSpec.describe DealPolicy do
  fixtures :users, :workspaces, :memberships, :companies

  let(:workspace) { workspaces(:one) }
  let(:admin) { users(:one) }
  let(:salesperson) { users(:two) }
  let(:sales_director) { users(:three) }
  let(:outsider) { users(:outsider) }
  let(:other_owner) { users(:two) }

  def context_for(user, ws = workspace)
    UserContext.new(user: user, workspace: ws)
  end

  let(:deal) do
    create_deal!(workspace, owner: admin)
  end

  describe "view and edit for owner vs other salesperson" do
    it "allows the owner to show and update" do
      deal.update!(owner: salesperson)
      policy = described_class.new(context_for(salesperson), deal)

      expect(policy.show?).to be true
      expect(policy.update?).to be true
      expect(policy.destroy?).to be true
    end

    it "forbids another salesperson without access" do
      deal.update!(owner: admin)
      policy = described_class.new(context_for(salesperson), deal)

      expect(policy.show?).to be false
      expect(policy.update?).to be false
    end

    it "allows a collaborator with deal access" do
      deal.update!(owner: admin)
      deal.deal_accesses.create!(user: salesperson)
      policy = described_class.new(context_for(salesperson), deal)

      expect(policy.show?).to be true
      expect(policy.update?).to be true
    end
  end

  describe "admin and sales director" do
    it "allows admin full record access" do
      deal.update!(owner: salesperson)
      policy = described_class.new(context_for(admin), deal)

      expect(policy.show?).to be true
      expect(policy.update?).to be true
    end

    it "allows sales director full record access" do
      deal.update!(owner: admin)
      policy = described_class.new(context_for(sales_director), deal)

      expect(policy.show?).to be true
      expect(policy.update?).to be true
    end
  end

  describe "ai salesperson" do
    let(:ai_user) { users(:outsider) }

    before { Membership.create!(user: ai_user, workspace: workspace, role: "ai_salesperson") }

    it "can show and update their own deals but never destroy them" do
      deal.update!(owner: ai_user)
      policy = described_class.new(context_for(ai_user), deal)

      expect(policy.show?).to be true
      expect(policy.update?).to be true
      expect(policy.destroy?).to be false
    end

    it "cannot see deals owned by others, even when shared or when workspace flags are on" do
      deal.update!(owner: admin)
      deal.deal_accesses.create!(user: ai_user)
      workspace.update!(salespeople_can_view_all_deals: true, salespeople_can_edit_all_deals: true)
      policy = described_class.new(context_for(ai_user), deal)

      expect(policy.show?).to be false
      expect(policy.update?).to be false
    end

    it "scopes deals to the ones they own" do
      owned = create_deal!(workspace, owner: ai_user, name: "Mine")
      shared = create_deal!(workspace, owner: admin, name: "Shared")
      shared.deal_accesses.create!(user: ai_user)
      create_deal!(workspace, owner: admin, name: "Other")

      scope = described_class::Scope.new(context_for(ai_user), Deal.all).resolve

      expect(scope).to contain_exactly(owned)
    end
  end

  describe "workspace deal visibility flags" do
    before { deal.update!(owner: admin) }

    it "allows view when salespeople_can_view_all_deals is enabled" do
      workspace.update!(salespeople_can_view_all_deals: true)
      policy = described_class.new(context_for(salesperson), deal)

      expect(policy.show?).to be true
      expect(policy.update?).to be false
    end

    it "allows edit when salespeople_can_edit_all_deals is enabled" do
      workspace.update!(salespeople_can_edit_all_deals: true)
      policy = described_class.new(context_for(salesperson), deal)

      expect(policy.show?).to be true
      expect(policy.update?).to be true
    end
  end

  describe "#manage_collaborators?" do
    it "allows admin, sales director, and owner" do
      deal.update!(owner: salesperson)

      expect(described_class.new(context_for(admin), deal).manage_collaborators?).to be true
      expect(described_class.new(context_for(sales_director), deal).manage_collaborators?).to be true
      expect(described_class.new(context_for(salesperson), deal).manage_collaborators?).to be true
    end

    it "forbids another salesperson" do
      deal.update!(owner: admin)
      policy = described_class.new(context_for(salesperson), deal)

      expect(policy.manage_collaborators?).to be false
    end
  end

  describe "Scope" do
    let!(:owned_deal) { create_deal!(workspace, owner: salesperson, name: "Owned") }
    let!(:shared_deal) do
      create_deal!(workspace, owner: admin, name: "Shared").tap do |d|
        d.deal_accesses.create!(user: salesperson)
      end
    end
    let!(:admin_only_deal) { create_deal!(workspace, owner: admin, name: "Admin only") }

    it "returns all deals for admin" do
      scope = described_class::Scope.new(context_for(admin), Deal.all).resolve
      expect(scope).to include(owned_deal, shared_deal, admin_only_deal)
    end

    it "returns owned and shared deals for a salesperson" do
      scope = described_class::Scope.new(context_for(salesperson), Deal.all).resolve
      expect(scope).to contain_exactly(owned_deal, shared_deal)
    end

    it "returns nothing for outsiders" do
      scope = described_class::Scope.new(context_for(outsider), Deal.all).resolve
      expect(scope).to be_empty
    end
  end
end
